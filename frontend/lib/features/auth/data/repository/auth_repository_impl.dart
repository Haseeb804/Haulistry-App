import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/repository/auth_repository.dart';

/// Implementation of AuthRepository using Firebase Auth + Neo4j Backend
class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final String _baseUrl = '${AppConstants.apiUrl}/api';

  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return null;

      // Get Firebase ID token
      final idToken = await user.getIdToken();
      if (idToken == null) return null;

      // Fetch user from Neo4j backend
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['user'] != null) {
          return UserEntity.fromJson(data['user']);
        }
      }
      
      return null;
    } catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
    }
  }

  @override
  Future<UserEntity> signInWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Sign in failed');

      // Get Firebase ID token
      final idToken = await user.getIdToken();
      if (idToken == null) throw Exception('Failed to get auth token');

      // Fetch user from Neo4j backend
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['user'] != null) {
          return UserEntity.fromJson(data['user']);
        }
      }

      // Extract the backend error message so it surfaces to the user instead
      // of being swallowed by the generic catch block below.
      String backendMessage = 'Sign in failed. Please try again.';
      try {
        final errData = json.decode(response.body) as Map<String, dynamic>;
        final detail = errData['detail']?.toString() ?? '';
        if (detail.isNotEmpty) backendMessage = detail;
      } catch (_) {}

      if (response.statusCode == 404) {
        throw Exception('Account not found. Please sign up first.');
      }
      throw Exception(backendMessage);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } on SocketException {
      throw Exception('Please check your internet connection and try again');
    } catch (e) {
      throw _toUserFacingException(e);
    }
  }

  @override
  Future<String> requestPhoneOtp({required String phoneNumber}) async {
    try {
      final normalizedPhone = _normalizePkPhoneToE164(phoneNumber);

      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': normalizedPhone}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final serverPhone = (data['data']?['phone'] as String?)?.trim();
        final debugOtp = (data['data']?['debugOtp'] as String?)?.trim();
        // Keep return shape compatible with current flow by using phone as token.
        final phoneToken = (serverPhone != null && serverPhone.isNotEmpty)
            ? serverPhone
            : normalizedPhone;
        return _buildVerificationPayload(phone: phoneToken, debugOtp: debugOtp);
      }

      final message = (data['message'] ?? data['detail'] ?? 'Failed to send OTP').toString();
      throw Exception(message);
    } catch (e) {
      throw _toUserFacingException(e);
    }
  }

  @override
  Future<void> precheckSignup({
    required String email,
    required String phone,
    required String role,
    String? cnic,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/signup/precheck'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email.trim(),
          'phone': _normalizePkPhoneToE164(phone),
          'role': role,
          if (cnic != null && cnic.trim().isNotEmpty) 'cnic': cnic.trim(),
        }),
      );

      if (response.statusCode == 200) {
        return;
      }

      String message = 'Signup precheck failed';
      try {
        final data = json.decode(response.body);
        message = (data['detail'] ?? data['message'] ?? message).toString();
      } catch (_) {}

      throw Exception(message);
    } catch (e) {
      throw _toUserFacingException(e);
    }
  }

  @override
  Future<UserEntity> verifyPhoneOtpAndSignIn({
    required String verificationId,
    required String smsCode,
    String? name,
    required String role,
    String? email,
  }) async {
    try {
      final verificationPhone = _extractPhoneFromVerificationPayload(verificationId);

      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': verificationPhone,
          'otp': smsCode.trim(),
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode != 200 || data['success'] != true) {
        final message = (data['message'] ?? data['detail'] ?? 'OTP verification failed').toString();
        throw Exception(message);
      }

      // Custom OTP verifies phone only. App sign-in remains email/password based.
      throw Exception('Phone OTP verified. Please sign in with email and password.');
    } catch (e) {
      throw _toUserFacingException(e);
    }
  }

  @override
  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    Uint8List? profileImage,
  }) async {
    try {
      // Create user in Firebase Auth
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Sign up failed');

      // Convert image to base64 if provided
      String? profileImageBase64;
      if (profileImage != null) {
        profileImageBase64 = 'data:image/jpeg;base64,${base64Encode(profileImage)}';
      }

      // Sync user data to Neo4j backend
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/sync'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'firebaseUid': user.uid,
          'email': email,
          'name': name,
          'phone': phone,
          'role': role,
          'isVerified': true,
          'isActive': true,
          if (profileImageBase64 != null) 'profileImageUrl': profileImageBase64,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to sync user to database');
      }

      final data = json.decode(response.body);
      if (data['success'] != true || data['user'] == null) {
        throw Exception('Failed to create user in database');
      }

      return UserEntity.fromJson(data['user']);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
    }
  }

  @override
  Future<UserEntity> completeSignUpWithPhoneVerification({
    required String verificationId,
    required String smsCode,
    required Map<String, dynamic> pendingSignupData,
  }) async {
    try {
      final normalizedPhone = _extractPhoneFromVerificationPayload(verificationId);

      // Step 1: Verify OTP against backend custom OTP service.
      final otpResponse = await http.post(
        Uri.parse('${AppConstants.apiUrl}/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': normalizedPhone,
          'otp': smsCode.trim(),
        }),
      );

      final otpData = json.decode(otpResponse.body);
      if (otpResponse.statusCode != 200 || otpData['success'] != true) {
        final message = (otpData['message'] ?? otpData['detail'] ?? 'OTP verification failed').toString();
        throw Exception(message);
      }

      final email = (pendingSignupData['email'] as String?)?.trim() ?? '';
      final password = (pendingSignupData['password'] as String?) ?? '';
      final name = (pendingSignupData['name'] as String?)?.trim() ?? '';
      final role = (pendingSignupData['role'] as String?)?.trim() ?? 'seeker';
      final rawPhone = (pendingSignupData['phone'] as String?)?.trim() ?? '';
      final phone = _normalizePkPhoneToE164(rawPhone);
      if (phone != normalizedPhone) {
        throw Exception('Phone mismatch. Please request OTP again.');
      }

      // Step 2: OTP is verified, now create account through existing flows.
      if (role == AppConstants.roleProvider) {
        return signUpProviderWithDocuments(
          email: email,
          password: password,
          name: name,
          phone: phone,
          profileImage: pendingSignupData['profileImage'] as Uint8List?,
          cnic: (pendingSignupData['cnic'] as String?)?.trim() ?? '',
          vehicleNumber: (pendingSignupData['vehicleNumber'] as String?)?.trim() ?? '',
          vehicleType: (pendingSignupData['vehicleType'] as String?)?.trim() ?? '',
          vehicleModel: (pendingSignupData['vehicleModel'] as String?)?.trim() ?? '',
          vehicleYear: (pendingSignupData['vehicleYear'] as String?)?.trim() ?? '',
          vehicleCapacity: (pendingSignupData['vehicleCapacity'] as num?)?.toDouble() ?? 0.0,
          cnicFrontImageBase64: pendingSignupData['cnicFrontImageBase64'] as String?,
          cnicBackImageBase64: pendingSignupData['cnicBackImageBase64'] as String?,
          licenseImageBase64: pendingSignupData['licenseImageBase64'] as String?,
          vehicleImageBase64: pendingSignupData['vehicleImageBase64'] as String?,
        );
      }

      return signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
        profileImage: pendingSignupData['profileImage'] as Uint8List?,
      );
    } catch (e) {
      throw _toUserFacingException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
    }
  }

  @override
  Future<UserEntity> updateProfile(UserEntity user) async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final idToken = await currentUser.getIdToken();
      if (idToken == null) throw Exception('Failed to get auth token');

      final response = await http.put(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(user.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['user'] != null) {
          try {
            final updatedUser = UserEntity.fromJson(data['user']);
            return updatedUser;
          } catch (parseError) {
            throw Exception('Failed to parse user data: $parseError');
          }
        }
        throw Exception('Invalid response format: ${response.body}');
      }

      throw Exception('Failed to update profile. Status: ${response.statusCode}, Body: ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> uploadProviderDocuments({
    required String userId,
    required String cnicFrontImagePath,
    required String cnicBackImagePath,
    required String licenseImagePath,
    required String vehicleImagePath,
    required String cnic,
    required String vehicleNumber,
    required String vehicleType,
    required String vehicleModel,
    required String vehicleYear,
    required double vehicleCapacity,
  }) async {
    try {
      // Update CNIC and vehicle info in Neo4j.
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final idToken = await currentUser.getIdToken();
      if (idToken == null) throw Exception('Failed to get auth token');

      await http.put(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'cnic': cnic,
          'isVerified': true,
          'vehicleType': vehicleType,
          'vehicleModel': vehicleModel,
          'vehicleYear': vehicleYear,
          'vehicleCapacity': vehicleCapacity,
          'vehicleNumber': vehicleNumber,
        }),
      );
    } catch (e) {
      throw Exception('Failed to upload documents: $e');
    }
  }

  @override
  Future<UserEntity> signUpProviderWithDocuments({
    required String email,
    required String password,
    required String name,
    required String phone,
    Uint8List? profileImage,
    required String cnic,
    required String vehicleNumber,
    required String vehicleType,
    required String vehicleModel,
    required String vehicleYear,
    required double vehicleCapacity,
    String? cnicFrontImageBase64,
    String? cnicBackImageBase64,
    String? licenseImageBase64,
    String? vehicleImageBase64,
  }) async {
    try {
      // Step 1: Create user in Firebase Auth
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Sign up failed');

      // Convert profile image to base64 if provided
      String? profileImageBase64;
      if (profileImage != null) {
        profileImageBase64 = 'data:image/jpeg;base64,${base64Encode(profileImage)}';
      }

      // Step 2: Sync user data to Neo4j backend with Base64 images
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/sync'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'firebaseUid': user.uid,
          'email': email,
          'name': name,
          'phone': phone,
          'role': 'provider',
          'isVerified': true,
          'isActive': true,
          if (profileImageBase64 != null) 'profileImageUrl': profileImageBase64,
          'cnic': cnic,
          'cnicFrontImageBase64': cnicFrontImageBase64,
          'cnicBackImageBase64': cnicBackImageBase64,
          'licenseImageBase64': licenseImageBase64,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to sync user to database');
      }

      final data = json.decode(response.body);
      if (data['success'] != true || data['user'] == null) {
        throw Exception('Failed to create user in database');
      }

      final userEntity = UserEntity.fromJson(data['user']);

      // Step 3: Create vehicle for the provider with Base64 image
      try {
        final idToken = await user.getIdToken();
        if (idToken != null) {
          final response = await http.post(
            Uri.parse('$_baseUrl/vehicles'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode({
              'providerId': userEntity.id,
              'vehicleType': vehicleType,
              'vehicleNumber': vehicleNumber,
              'vehicleModel': vehicleModel,
              'vehicleYear': vehicleYear,
              'capacity': vehicleCapacity,
              'vehicleImageBase64': vehicleImageBase64,
              'isAvailable': true,
            }),
          );

          if (response.statusCode != 200 && response.statusCode != 201) {
            throw Exception('Failed to create provider vehicle profile');
          }
        }
      } catch (vehicleError) {
        // Vehicle creation is non-blocking for signup completion.
        // Intentionally swallowed to avoid failing account creation.
      }

      return userEntity;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'operation-not-allowed':
        return 'Operation not allowed';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'network-request-failed':
        return 'Please check your internet connection and try again';
      case 'invalid-phone-number':
        return 'Invalid phone number format';
      case 'invalid-app-credential':
        return 'Phone authentication is misconfigured for this app build. Check Firebase app package/bundle and SHA fingerprints.';
      case 'app-not-authorized':
        return 'This app is not authorized to use Firebase Authentication. Check Firebase app setup.';
      case 'missing-client-identifier':
        return 'Missing app client identifier. Recheck Firebase configuration files.';
      case 'quota-exceeded':
        return 'OTP request limit exceeded. Please try again later.';
      case 'billing-not-enabled':
        return 'Phone authentication requires billing to be enabled for this Firebase project. Please enable billing in Google Cloud/Firebase and try again.';
      case 'internal-error':
        return 'Firebase temporary error. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-verification-code':
        return 'Invalid OTP code';
      case 'invalid-verification-id':
        return 'Invalid OTP session. Please request a new code.';
      case 'session-expired':
        return 'OTP session expired. Please request a new code';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed. Please try again';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      case 'provider-already-linked':
        return 'This sign-in method is already linked to your account.';
      default:
        return 'Authentication failed ($code)';
    }
  }

  String _normalizePkPhoneToE164(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (digits.startsWith('+')) {
      return digits;
    }

    if (digits.startsWith('03') && digits.length == 11) {
      // 03XXXXXXXXX -> +923XXXXXXXXX
      return '+92${digits.substring(1)}';
    }

    if (digits.startsWith('92') && digits.length == 12) {
      return '+$digits';
    }

    // If already entered as local digits without 0 (3XXXXXXXXX)
    if (digits.startsWith('3') && digits.length == 10) {
      return '+92$digits';
    }

    return digits;
  }

  String _buildVerificationPayload({
    required String phone,
    String? debugOtp,
  }) {
    final payload = {
      'phone': phone,
      if (debugOtp != null && debugOtp.isNotEmpty) 'debugOtp': debugOtp,
    };
    return json.encode(payload);
  }

  String _extractPhoneFromVerificationPayload(String verificationPayload) {
    try {
      final decoded = json.decode(verificationPayload);
      if (decoded is Map<String, dynamic>) {
        final phone = (decoded['phone'] as String?)?.trim();
        if (phone != null && phone.isNotEmpty) {
          return _normalizePkPhoneToE164(phone);
        }
      }
    } catch (_) {
      // backward compatibility: payload may already be plain phone
    }

    return _normalizePkPhoneToE164(verificationPayload);
  }

  /// Get user-friendly message for network errors
  String _getNetworkErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (error is SocketException ||
        errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('no address associated')) {
      return 'Please check your internet connection and try again';
    } else if (errorStr.contains('timeout')) {
      return 'Connection timed out. Please check your internet and try again';
    }
    return 'Something went wrong. Please try again later';
  }

  Exception _toUserFacingException(dynamic error) {
    final raw = error.toString();
    final normalized = raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
    final lower = normalized.toLowerCase();

    if (error is SocketException ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('no address associated') ||
        lower.contains('timeout')) {
      return Exception(_getNetworkErrorMessage(error));
    }

    if (normalized.trim().isNotEmpty && normalized.trim() != 'null') {
      return Exception(normalized.trim());
    }

    return Exception('Something went wrong. Please try again later');
  }

  @override
  Future<void> updateFcmToken(String fcmToken) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final idToken = await user.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get auth token');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({'fcm_token': fcmToken}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update FCM token');
      }
    } catch (e) {
      // Silently fail - FCM token update is not critical
    }
  }
}
