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
  final String role;
  final Map<String, dynamic> pendingSignupData;

  const AuthPendingPhoneVerification({
    required this.verificationId,
    required this.phoneNumber,
    required this.role,
    required this.pendingSignupData,
  });

  @override
  List<Object?> get props =>
      [verificationId, phoneNumber, role, pendingSignupData];
}
