import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
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
      
      throw Exception('User data not found in database');
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
    }
  }

  @override
  Future<String> requestPhoneOtp({required String phoneNumber}) async {
    final normalizedPhone = _normalizePkPhoneToE164(phoneNumber);
    final completer = Completer<String>();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval may complete instantly on Android in some cases.
          // We keep this non-blocking because UI flow proceeds from verificationId.
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(Exception(_getAuthErrorMessage(e.code)));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
      );

      return completer.future;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
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
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Phone sign-in failed');
      }

      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get auth token');
      }

      // Try existing user first
      final meResponse = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (meResponse.statusCode == 200) {
        final meData = json.decode(meResponse.body);
        if (meData['success'] == true && meData['user'] != null) {
          return UserEntity.fromJson(meData['user']);
        }
      }

      // Create/sync user for first-time phone-auth login
      final syncResponse = await http.post(
        Uri.parse('$_baseUrl/auth/phone/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          'role': role,
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        }),
      );

      if (syncResponse.statusCode == 200 || syncResponse.statusCode == 201) {
        final syncData = json.decode(syncResponse.body);
        if (syncData['success'] == true && syncData['user'] != null) {
          return UserEntity.fromJson(syncData['user']);
        }
      }

      throw Exception('Failed to sync phone-auth user');
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
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
      // Step 1: Verify phone OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('User not authenticated');
      }

      final email = (pendingSignupData['email'] as String?)?.trim() ?? '';
      final password = (pendingSignupData['password'] as String?) ?? '';
      final name = (pendingSignupData['name'] as String?)?.trim() ?? '';
      final role = (pendingSignupData['role'] as String?)?.trim() ?? 'seeker';
      final phone = (pendingSignupData['phone'] as String?)?.trim() ?? '';
      final profileImage = pendingSignupData['profileImage'] as Uint8List?;

      // Step 2: Link email/password credential after OTP success (if provided)
      if (email.isNotEmpty && password.isNotEmpty) {
        final emailCredential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        try {
          await firebaseUser.linkWithCredential(emailCredential);
        } on FirebaseAuthException catch (e) {
          if (e.code != 'provider-already-linked') {
            throw Exception(_getAuthErrorMessage(e.code));
          }
        }
      }

      await firebaseUser.getIdToken(true);
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get auth token');
      }

      // Step 3: Finalize signup in backend after OTP verification
      String? profileImageBase64;
      if (profileImage != null) {
        profileImageBase64 = 'data:image/jpeg;base64,${base64Encode(profileImage)}';
      }

      String? cnicFrontImageUrl;
      String? cnicBackImageUrl;
      String? licenseImageUrl;
      String? vehicleImageUrl;

      if (role == 'provider') {
        cnicFrontImageUrl = await _uploadProviderDocFromBase64(
          uid: firebaseUser.uid,
          base64Data: pendingSignupData['cnicFrontImageBase64'] as String?,
          fileName: 'cnic_front.jpg',
        );
        cnicBackImageUrl = await _uploadProviderDocFromBase64(
          uid: firebaseUser.uid,
          base64Data: pendingSignupData['cnicBackImageBase64'] as String?,
          fileName: 'cnic_back.jpg',
        );
        licenseImageUrl = await _uploadProviderDocFromBase64(
          uid: firebaseUser.uid,
          base64Data: pendingSignupData['licenseImageBase64'] as String?,
          fileName: 'license.jpg',
        );
        vehicleImageUrl = await _uploadProviderDocFromBase64(
          uid: firebaseUser.uid,
          base64Data: pendingSignupData['vehicleImageBase64'] as String?,
          fileName: 'vehicle.jpg',
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/signup/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'email': email,
          'name': name,
          'phone': phone,
          'role': role,
          if (profileImageBase64 != null) 'profileImageUrl': profileImageBase64,
          if (pendingSignupData['cnic'] != null) 'cnic': pendingSignupData['cnic'],
          if (pendingSignupData['cnicFrontImageBase64'] != null)
            'cnicFrontImageBase64': pendingSignupData['cnicFrontImageBase64'],
          if (pendingSignupData['cnicBackImageBase64'] != null)
            'cnicBackImageBase64': pendingSignupData['cnicBackImageBase64'],
          if (pendingSignupData['licenseImageBase64'] != null)
            'licenseImageBase64': pendingSignupData['licenseImageBase64'],
          if (pendingSignupData['vehicleImageBase64'] != null)
            'vehicleImageBase64': pendingSignupData['vehicleImageBase64'],
          if (cnicFrontImageUrl != null) 'cnicFrontImageUrl': cnicFrontImageUrl,
          if (cnicBackImageUrl != null) 'cnicBackImageUrl': cnicBackImageUrl,
          if (licenseImageUrl != null) 'licenseImageUrl': licenseImageUrl,
          if (vehicleImageUrl != null) 'vehicleImageUrl': vehicleImageUrl,
          if (pendingSignupData['vehicleType'] != null)
            'vehicleType': pendingSignupData['vehicleType'],
          if (pendingSignupData['vehicleNumber'] != null)
            'vehicleNumber': pendingSignupData['vehicleNumber'],
          if (pendingSignupData['vehicleModel'] != null)
            'vehicleModel': pendingSignupData['vehicleModel'],
          if (pendingSignupData['vehicleYear'] != null)
            'vehicleYear': pendingSignupData['vehicleYear'],
          if (pendingSignupData['vehicleCapacity'] != null)
            'vehicleCapacity': pendingSignupData['vehicleCapacity'],
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        try {
          await firebaseUser.delete();
        } catch (_) {
          // best effort rollback of Firebase Auth account
        }

        String message = 'Failed to complete signup';
        try {
          final data = json.decode(response.body);
          message = (data['detail'] ?? data['message'] ?? message).toString();
        } catch (_) {}
        throw Exception(message);
      }

      final data = json.decode(response.body);
      if (data['success'] != true || data['user'] == null) {
        throw Exception('Failed to finalize signup');
      }

      return UserEntity.fromJson(data['user']);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw _toUserFacingException(e);
    }
  }

  String _stripDataUrlPrefix(String input) {
    final commaIndex = input.indexOf(',');
    if (commaIndex != -1) {
      return input.substring(commaIndex + 1);
    }
    return input;
  }

  Future<String?> _uploadProviderDocFromBase64({
    required String uid,
    required String? base64Data,
    required String fileName,
  }) async {
    if (base64Data == null || base64Data.trim().isEmpty) {
      return null;
    }

    final cleaned = _stripDataUrlPrefix(base64Data.trim());
    final bytes = base64Decode(cleaned);

    final ref = FirebaseStorage.instance
        .ref()
        .child('provider_documents')
        .child(uid)
        .child(fileName);

    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(bytes, metadata);
    return ref.getDownloadURL();
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
      // TODO: Implement document upload with backend API
      // For now, just update CNIC and vehicle info in Neo4j
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
        return 'SMS quota exceeded. Please try again later.';
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
