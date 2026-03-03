import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import '../../../../core/domain/entities/user_entity.dart';
import '../../domain/repository/auth_repository.dart';

/// Implementation of AuthRepository using Firebase Auth + Neo4j Backend
class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final String _baseUrl = 'http://127.0.0.1:4000/api';

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
      throw Exception('Failed to get current user: $e');
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
      throw Exception('Sign in failed: $e');
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
      throw Exception('Sign up failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Password reset failed: $e');
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

      print('Update profile response status: ${response.statusCode}');
      print('Update profile response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['user'] != null) {
          print('Parsing user data: ${data['user']}');
          try {
            final updatedUser = UserEntity.fromJson(data['user']);
            print('Successfully parsed user: ${updatedUser.name}, ${updatedUser.email}');
            return updatedUser;
          } catch (parseError) {
            print('Error parsing user data: $parseError');
            throw Exception('Failed to parse user data: $parseError');
          }
        }
        throw Exception('Invalid response format: ${response.body}');
      }

      throw Exception('Failed to update profile. Status: ${response.statusCode}, Body: ${response.body}');
    } catch (e) {
      print('Update profile error: $e');
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
          final vehicleResponse = await http.post(
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
        }
      } catch (vehicleError) {
      }

      return userEntity;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Sign up failed: $e');
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
      default:
        return 'Authentication failed';
    }
  }
}
