import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repository/auth_repository.dart';
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
      final user = await _authRepository.signUpWithEmail(
        email: event.email,
        password: event.password,
        name: event.name,
        phone: event.phone,
        role: event.role,        profileImage: event.profileImage,      );
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
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
      final user = await _authRepository.signUpProviderWithDocuments(
        email: event.email,
        password: event.password,
        name: event.name,
        phone: event.phone,
        profileImage: event.profileImage,
        cnic: event.cnic,
        vehicleNumber: event.vehicleNumber,
        vehicleType: event.vehicleType,
        vehicleModel: event.vehicleModel,
        vehicleYear: event.vehicleYear,
        vehicleCapacity: event.vehicleCapacity,
        cnicFrontImageBase64: event.cnicFrontImageBase64,
        cnicBackImageBase64: event.cnicBackImageBase64,
        licenseImageBase64: event.licenseImageBase64,
        vehicleImageBase64: event.vehicleImageBase64,
      );
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
}
