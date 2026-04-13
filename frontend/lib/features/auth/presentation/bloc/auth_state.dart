import 'package:equatable/equatable.dart';
import '../../../../core/domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthPasswordResetSent extends AuthState {
  const AuthPasswordResetSent();
}

class AuthDocumentsUploaded extends AuthState {
  const AuthDocumentsUploaded();
}

class AuthPhoneCodeSent extends AuthState {
  final String verificationId;
  final String phoneNumber;
  final DateTime sentAt;

  const AuthPhoneCodeSent({
    required this.verificationId,
    required this.phoneNumber,
    required this.sentAt,
  });

  @override
  List<Object?> get props => [verificationId, phoneNumber, sentAt];
}

/// Pending phone verification after email signup
class AuthPendingPhoneVerification extends AuthState {
  final String verificationId;
  final String phoneNumber;
  final String firebaseUid;
  final String email;
  final String name;
  final String role;

  const AuthPendingPhoneVerification({
    required this.verificationId,
    required this.phoneNumber,
    required this.firebaseUid,
    required this.email,
    required this.name,
    required this.role,
  });

  @override
  List<Object?> get props =>
      [verificationId, phoneNumber, firebaseUid, email, name, role];
}
