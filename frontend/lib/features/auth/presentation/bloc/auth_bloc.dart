import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repository/auth_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/notification_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthPhoneOtpRequested>(_onPhoneOtpRequested);
    on<AuthPhoneOtpVerifyRequested>(_onPhoneOtpVerifyRequested);
    on<AuthSignUpWithPhoneVerifyRequested>(_onSignUpWithPhoneVerifyRequested);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
    on<AuthProfileUpdateRequested>(_onProfileUpdateRequested);
    on<AuthUpdateProfileRequested>(_onUpdateProfileRequested);
    on<AuthDocumentsUploadRequested>(_onDocumentsUploadRequested);
    on<AuthProviderSignUpWithDocuments>(_onProviderSignUpWithDocuments);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        // Update FCM token on app start if already authenticated
        _updateFcmToken();
        emit(AuthAuthenticated(user: user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.signInWithEmail(
        event.email,
        event.password,
      );
      
      // Update FCM token after successful login
      _updateFcmToken();
      
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // Step 1: Precheck duplicates before sending OTP
      await _authRepository.precheckSignup(
        email: event.email,
        phone: event.phone,
        role: event.role,
      );

      // Step 2: Request OTP for phone verification
      final verificationId = await _authRepository.requestPhoneOtp(
        phoneNumber: event.phone,
      );

      // Step 3: Keep full signup data in memory and continue on OTP screen
      final pendingSignupData = {
        'email': event.email,
        'password': event.password,
        'name': event.name,
        'phone': event.phone,
        'role': event.role,
        'profileImage': event.profileImage,
      };

      emit(AuthPendingPhoneVerification(
        verificationId: verificationId,
        phoneNumber: event.phone,
        role: event.role,
        pendingSignupData: pendingSignupData,
      ));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Update FCM token in backend (fire and forget)
  void _updateFcmToken() async {
    try {
      final fcmToken = await NotificationService().getToken();
      if (fcmToken != null) {
        await _authRepository.updateFcmToken(fcmToken);
      }
    } catch (e) {
      // Silently fail - FCM token update is not critical
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onPhoneOtpRequested(
    AuthPhoneOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final verificationId = await _authRepository.requestPhoneOtp(
        phoneNumber: event.phoneNumber,
      );

      emit(AuthPhoneCodeSent(
        verificationId: verificationId,
        phoneNumber: event.phoneNumber,
        sentAt: DateTime.now(),
      ));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onPhoneOtpVerifyRequested(
    AuthPhoneOtpVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.verifyPhoneOtpAndSignIn(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
        name: event.name,
        role: event.role,
        email: event.email,
      );

      _updateFcmToken();
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onSignUpWithPhoneVerifyRequested(
    AuthSignUpWithPhoneVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // Verify OTP and finalize signup in Firebase + backend
      final user = await _authRepository.completeSignUpWithPhoneVerification(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
        pendingSignupData: event.pendingSignupData,
      );

      _updateFcmToken();
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.resetPassword(event.email);
      emit(const AuthPasswordResetSent());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onProfileUpdateRequested(
    AuthProfileUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.updateProfile(event.user);
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onUpdateProfileRequested(
    AuthUpdateProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Get current user from state BEFORE emitting loading
      final currentState = state;
      if (currentState is! AuthAuthenticated) {
        throw Exception('User not authenticated');
      }

      emit(const AuthLoading());

      // Create updated user entity with new values
      final updatedUser = currentState.user.copyWith(
        name: event.name,
        phone: event.phone,
        address: event.address,
        cnic: event.cnic,
        drivingLicense: event.drivingLicense,
        profileImageUrl: event.profileImageUrl,
      );

      // Update profile in backend
      final user = await _authRepository.updateProfile(updatedUser);
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onDocumentsUploadRequested(
    AuthDocumentsUploadRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.uploadProviderDocuments(
        userId: event.userId,
        cnicFrontImagePath: event.cnicFrontImagePath,
        cnicBackImagePath: event.cnicBackImagePath,
        licenseImagePath: event.licenseImagePath,
        vehicleImagePath: event.vehicleImagePath,
        cnic: event.cnic,
        vehicleNumber: event.vehicleNumber,
        vehicleType: event.vehicleType,
        vehicleModel: event.vehicleModel,
        vehicleYear: event.vehicleYear,
        vehicleCapacity: event.vehicleCapacity,
      );
      emit(const AuthDocumentsUploaded());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onProviderSignUpWithDocuments(
    AuthProviderSignUpWithDocuments event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.precheckSignup(
        email: event.email,
        phone: event.phone,
        role: AppConstants.roleProvider,
        cnic: event.cnic,
      );

      final verificationId = await _authRepository.requestPhoneOtp(
        phoneNumber: event.phone,
      );

      final pendingSignupData = {
        'email': event.email,
        'password': event.password,
        'name': event.name,
        'phone': event.phone,
        'role': AppConstants.roleProvider,
        'profileImage': event.profileImage,
        'cnic': event.cnic,
        'vehicleNumber': event.vehicleNumber,
        'vehicleType': event.vehicleType,
        'vehicleModel': event.vehicleModel,
        'vehicleYear': event.vehicleYear,
        'vehicleCapacity': event.vehicleCapacity,
        'cnicFrontImageBase64': event.cnicFrontImageBase64,
        'cnicBackImageBase64': event.cnicBackImageBase64,
        'licenseImageBase64': event.licenseImageBase64,
        'vehicleImageBase64': event.vehicleImageBase64,
        'vehicleExtraFields': event.vehicleExtraFields,
      };

      emit(AuthPendingPhoneVerification(
        verificationId: verificationId,
        phoneNumber: event.phone,
        role: AppConstants.roleProvider,
        pendingSignupData: pendingSignupData,
      ));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
}
