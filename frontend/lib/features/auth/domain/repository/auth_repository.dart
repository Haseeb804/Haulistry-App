import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/domain/entities/user_entity.dart';

/// Repository for authentication operations
abstract class AuthRepository {
  /// Get current user
  Future<UserEntity?> getCurrentUser();
  
  /// Sign in with email and password
  Future<UserEntity> signInWithEmail(String email, String password);

  /// Request Firebase OTP for phone authentication
  Future<String> requestPhoneOtp({required String phoneNumber});

  /// Verify OTP and sign in with phone, then sync/fetch user from backend
  Future<UserEntity> verifyPhoneOtpAndSignIn({
    required String verificationId,
    required String smsCode,
    String? name,
    required String role,
    String? email,
  });

  /// Complete email signup after phone OTP verification (don't persist until verified)
  Future<UserEntity> completeSignUpWithPhoneVerification({
    required String verificationId,
    required String smsCode,
    required String firebaseUid,
    required String email,
    required String name,
    required String phone,
    required String role,
    Uint8List? profileImage,
  });
  
  /// Sign up with email and password
  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    Uint8List? profileImage,
  });
  
  /// Sign out
  Future<void> signOut();
  
  /// Reset password
  Future<void> resetPassword(String email);
  
  /// Update user profile
  Future<UserEntity> updateProfile(UserEntity user);
  
  /// Upload provider documents
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
  });
  
  /// Sign up provider with documents (two-step registration)
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
  });
  
  /// Update FCM token for push notifications
  Future<void> updateFcmToken(String fcmToken);
  
  /// Stream of auth state changes
  Stream<User?> get authStateChanges;
}
