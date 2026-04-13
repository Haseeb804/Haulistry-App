import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
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
  final _otpFormKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String? _verificationId;

  // OTP expiration timer (30 seconds)
  static const int _otpExpirationSeconds = 30;
  int _remainingSeconds = 0;
  Timer? _otpTimer;
  bool _isOtpExpired = false;

  bool _isValidSignupContext = false;
  Map<String, dynamic>? _pendingSignupData;

  @override
  void initState() {
    super.initState();
    _parseExtraData();
    if (_isValidSignupContext && _verificationId != null) {
      _startOtpTimer();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP is only available during signup flow.')),
        );
        context.go('/signup');
      });
    }
  }

  void _parseExtraData() {
    final extra = widget.extra;
    if (extra == null) return;

    final isSignUpFlow = extra['isSignUpFlow'] == true;
    final verificationId = extra['verificationId'] as String?;
    final pendingSignupData = extra['pendingSignupData'] as Map<String, dynamic>?;
    final phoneNumber = extra['phoneNumber'] as String?;

    if (isSignUpFlow && verificationId != null && pendingSignupData != null && phoneNumber != null) {
      _isValidSignupContext = true;
      _verificationId = verificationId;
      _pendingSignupData = pendingSignupData;
      _phoneController.text = phoneNumber;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  void _verifyOtp() {
    if (_otpFormKey.currentState!.validate() &&
        _verificationId != null &&
        _pendingSignupData != null) {
      context.read<AuthBloc>().add(
            AuthSignUpWithPhoneVerifyRequested(
              verificationId: _verificationId!,
              smsCode: _otpController.text.trim(),
              pendingSignupData: _pendingSignupData!,
            ),
          );
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
      _otpController.clear();
      _remainingSeconds = 0;
      _isOtpExpired = false;
    });
    context.go('/signup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone Number'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/signup'),
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
                  'Enter verification code',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your SMS inbox and enter the 6-digit code to complete signup.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),

                Form(
                    key: _otpFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _phoneController,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                              onPressed: isLoading
                                  ? null
                                  : () {
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
