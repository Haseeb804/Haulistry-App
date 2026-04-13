import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class PhoneAuthScreen extends StatefulWidget {
  final Map<String, dynamic>? extra;

  const PhoneAuthScreen({this.extra, super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedRole = AppConstants.roleSeeker;
  String? _verificationId;
  
  // Signup flow context (if coming from signup)
  late bool _isSignUpFlow;
  
    // OTP expiration timer (30 seconds)
    static const int _otpExpirationSeconds = 30;
    int _remainingSeconds = 0;
    Timer? _otpTimer;
    bool _isOtpExpired = false;
  late String? _firebaseUid;
  late String? _signupEmail;
  late String? _signupName;
  late String? _signupPassword;

  @override
  void initState() {
    super.initState();
    _parseExtraData();
    if (_verificationId != null) {
      _startOtpTimer();
    }
  }

  void _parseExtraData() {
    final extra = widget.extra;
    if (extra != null) {
      _isSignUpFlow = extra['isSignUpFlow'] ?? false;
      _verificationId = extra['verificationId'];
      _firebaseUid = extra['firebaseUid'];
      _signupEmail = extra['email'];
      _signupName = extra['name'];
      _signupPassword = extra['password'];
      _selectedRole = extra['role'] ?? AppConstants.roleSeeker;
      
      // Pre-fill fields from signup context
      if (extra['phoneNumber'] != null) {
        _phoneController.text = extra['phoneNumber'];
      }
      if (_signupName != null) {
        _nameController.text = _signupName!;
      }
      if (_signupEmail != null) {
        _emailController.text = _signupEmail!;
      }
    } else {
      _isSignUpFlow = false;
      _firebaseUid = null;
      _signupEmail = null;
      _signupName = null;
      _signupPassword = null;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  void _requestOtp() {
    if (_phoneFormKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            AuthPhoneOtpRequested(phoneNumber: _phoneController.text.trim()),
          );
    }
  }

  void _verifyOtp() {
    if (_otpFormKey.currentState!.validate() && _verificationId != null) {
      if (_isSignUpFlow && _firebaseUid != null) {
        // Signup flow: emit AuthSignUpWithPhoneVerifyRequested
        context.read<AuthBloc>().add(
              AuthSignUpWithPhoneVerifyRequested(
                verificationId: _verificationId!,
                smsCode: _otpController.text.trim(),
                firebaseUid: _firebaseUid!,
                email: _signupEmail ?? '',
                password: _signupPassword ?? '',
                name: _signupName ?? '',
                phone: _phoneController.text.trim(),
                role: _selectedRole,
              ),
            );
      } else {
        // Direct phone login flow: emit AuthPhoneOtpVerifyRequested
        context.read<AuthBloc>().add(
              AuthPhoneOtpVerifyRequested(
                verificationId: _verificationId!,
                smsCode: _otpController.text.trim(),
                role: _selectedRole,
                name: _nameController.text.trim().isEmpty
                    ? null
                    : _nameController.text.trim(),
                email: _emailController.text.trim().isEmpty
                    ? null
                    : _emailController.text.trim(),
              ),
            );
      }
    }
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    _remainingSeconds = _otpExpirationSeconds;
    _isOtpExpired = false;

    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _isOtpExpired = true;
          timer.cancel();
        }
      });
    });
  }

  void _resetOtpFlow() {
    _otpTimer?.cancel();
    setState(() {
      _verificationId = null;
      _otpController.clear();
      _remainingSeconds = 0;
      _isOtpExpired = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_isSignUpFlow) {
              context.go('/signup');
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthPhoneCodeSent) {
            setState(() {
              _verificationId = state.verificationId;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP sent successfully.')),
            );
            _startOtpTimer();
          } else if (state is AuthAuthenticated) {
            if (state.user.role == AppConstants.roleProvider && !state.user.isVerified) {
              context.go('/provider/documents');
            } else if (state.user.role == AppConstants.roleProvider) {
              context.go('/provider/home');
            } else {
              context.go('/seeker/home');
            }
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  _verificationId == null
                      ? 'Sign in with OTP'
                      : 'Enter verification code',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _verificationId == null
                      ? 'We will send a one-time password to your phone number.'
                      : 'Check your SMS inbox and enter the 6-digit code.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),

                if (_verificationId == null)
                  Form(
                    key: _phoneFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '03001234567',
                            prefixIcon: Icon(Icons.phone_rounded),
                          ),
                          validator: Validators.phone,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),
                        if (!_isSignUpFlow)
                          Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _selectedRole,
                                decoration: const InputDecoration(
                                  labelText: 'Role',
                                  prefixIcon: Icon(Icons.badge_rounded),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: AppConstants.roleSeeker,
                                    child: Text('Seeker'),
                                  ),
                                  DropdownMenuItem(
                                    value: AppConstants.roleProvider,
                                    child: Text('Provider'),
                                  ),
                                ],
                                onChanged: isLoading
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() => _selectedRole = value);
                                        }
                                      },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name (optional for first login)',
                                  prefixIcon: Icon(Icons.person_rounded),
                                ),
                                enabled: !isLoading,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email (optional)',
                                  prefixIcon: Icon(Icons.email_rounded),
                                ),
                                enabled: !isLoading,
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: isLoading ? null : _requestOtp,
                          icon: const Icon(Icons.sms_rounded),
                          label: Text(isLoading ? 'Sending...' : 'Send OTP'),
                        ),
                      ],
                    ),
                  )
                else
                  Form(
                    key: _otpFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'OTP Code',
                            hintText: '123456',
                            prefixIcon: Icon(Icons.verified_user_rounded),
                          ),
                          validator: (value) {
                            final code = value?.trim() ?? '';
                            if (code.isEmpty) return 'OTP is required';
                            if (code.length != 6) return 'OTP must be 6 digits';
                            if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                              return 'OTP must contain only digits';
                            }
                            return null;
                          },
                          enabled: !isLoading && !_isOtpExpired,
                        ),
                        const SizedBox(height: 8),
                        if (_isOtpExpired)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.1),
                              border: Border.all(color: AppTheme.errorColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_off_rounded, color: AppTheme.errorColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'OTP expired. Please request a new one.',
                                    style: TextStyle(
                                      color: AppTheme.errorColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Resend in ${_remainingSeconds}s',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (_isOtpExpired)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Requesting new OTP...')),
                                );
                                context.read<AuthBloc>().add(
                                  AuthPhoneOtpRequested(
                                    phoneNumber: _phoneController.text.trim(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Request New OTP'),
                            ),
                          )
                        else
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: isLoading
                                  ? null
                                  : _resetOtpFlow,
                              child: const Text('Use different phone number'),
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: (isLoading || _isOtpExpired) ? null : _verifyOtp,
                          icon: const Icon(Icons.login_rounded),
                          label: Text(
                            _isOtpExpired
                                ? 'OTP Expired'
                                : (isLoading ? 'Verifying...' : 'Verify & Continue'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
