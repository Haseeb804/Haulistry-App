import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import '../../../../core/domain/entities/user_entity.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthSignInRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String phone;
  final String role;
  final Uint8List? profileImage;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
    required this.role,
    this.profileImage,
  });

  @override
  List<Object?> get props => [
        email,
        password,
        name,
        phone,
        role,
        profileImage,
      ];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

class AuthPhoneOtpRequested extends AuthEvent {
  final String phoneNumber;

  const AuthPhoneOtpRequested({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}

class AuthPhoneOtpVerifyRequested extends AuthEvent {
  final String verificationId;
  final String smsCode;
  final String role;
  final String? name;
  final String? email;

  const AuthPhoneOtpVerifyRequested({
    required this.verificationId,
    required this.smsCode,
    required this.role,
    this.name,
    this.email,
  });

  @override
  List<Object?> get props => [verificationId, smsCode, role, name, email];
}

/// Complete signup with phone verification
class AuthSignUpWithPhoneVerifyRequested extends AuthEvent {
  final String verificationId;
  final String smsCode;
  final Map<String, dynamic> pendingSignupData;

  const AuthSignUpWithPhoneVerifyRequested({
    required this.verificationId,
    required this.smsCode,
    required this.pendingSignupData,
  });

  @override
  List<Object?> get props => [
        verificationId,
        smsCode,
        pendingSignupData,
      ];
}

class AuthPasswordResetRequested extends AuthEvent {
  final String email;

  const AuthPasswordResetRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthProfileUpdateRequested extends AuthEvent {
  final UserEntity user;

  const AuthProfileUpdateRequested({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthUpdateProfileRequested extends AuthEvent {
  final String name;
  final String phone;
  final String address;
  final String cnic;
  final String drivingLicense;
  final String? profileImageUrl;

  const AuthUpdateProfileRequested({
    required this.name,
    required this.phone,
    required this.address,
    required this.cnic,
    required this.drivingLicense,
    this.profileImageUrl,
  });

  @override
  List<Object?> get props => [
        name,
        phone,
        address,
        cnic,
        drivingLicense,
        profileImageUrl,
      ];
}

class AuthDocumentsUploadRequested extends AuthEvent {
  final String userId;
  final String cnicFrontImagePath;
  final String cnicBackImagePath;
  final String licenseImagePath;
  final String vehicleImagePath;
  final String cnic;
  final String vehicleNumber;
  final String vehicleType;
  final String vehicleModel;
  final String vehicleYear;
  final double vehicleCapacity;
  // Cross-platform image bytes for web upload
  final Uint8List? cnicFrontImageBytes;
  final Uint8List? cnicBackImageBytes;
  final Uint8List? licenseImageBytes;
  final Uint8List? vehicleImageBytes;

  const AuthDocumentsUploadRequested({
    required this.userId,
    required this.cnicFrontImagePath,
    required this.cnicBackImagePath,
    required this.licenseImagePath,
    required this.vehicleImagePath,
    required this.cnic,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehicleCapacity,
    this.cnicFrontImageBytes,
    this.cnicBackImageBytes,
    this.licenseImageBytes,
    this.vehicleImageBytes,
  });

  @override
  List<Object?> get props => [
        userId,
        cnicFrontImagePath,
        cnicBackImagePath,
        licenseImagePath,
        vehicleImagePath,
        cnic,
        vehicleNumber,
        vehicleType,
        vehicleModel,
        vehicleYear,
        vehicleCapacity,
        cnicFrontImageBytes,
        cnicBackImageBytes,
        licenseImageBytes,
        vehicleImageBytes,
      ];
}

/// Event for provider signup with documents (two-step registration)
class AuthProviderSignUpWithDocuments extends AuthEvent {
  // Personal info from signup screen
  final String email;
  final String password;
  final String name;
  final String phone;
  final Uint8List? profileImage;
  
  // Document info
  final String cnic;
  final String vehicleNumber;
  final String vehicleType;
  final String vehicleModel;
  final String vehicleYear;
  final double vehicleCapacity;
  
  // Base64 encoded images
  final String? cnicFrontImageBase64;
  final String? cnicBackImageBase64;
  final String? licenseImageBase64;
  final String? vehicleImageBase64;

  final String? vehicleLicenseImageBase64;

  const AuthProviderSignUpWithDocuments({
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
    this.profileImage,
    required this.cnic,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehicleCapacity,
    this.cnicFrontImageBase64,
    this.cnicBackImageBase64,
    this.licenseImageBase64,
    this.vehicleImageBase64,
    this.vehicleLicenseImageBase64,
  });

  @override
  List<Object?> get props => [
        email,
        password,
        name,
        phone,
        profileImage,
        cnic,
        vehicleNumber,
        vehicleType,
        vehicleModel,
        vehicleYear,
        vehicleCapacity,
        cnicFrontImageBase64,
        cnicBackImageBase64,
        licenseImageBase64,
        vehicleImageBase64,
        vehicleLicenseImageBase64,
      ];
}
