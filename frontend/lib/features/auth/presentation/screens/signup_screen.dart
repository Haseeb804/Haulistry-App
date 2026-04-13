import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/cross_platform_image_picker.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = AppConstants.roleSeeker;
  Uint8List? _profileImage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignup() {
    if (_formKey.currentState!.validate()) {
      // Check if profile image is selected
      if (_profileImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Please add a profile photo')),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      // For providers, navigate to documents screen with signup data
      if (_selectedRole == AppConstants.roleProvider) {
        context.go('/provider/documents', extra: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'profileImage': _profileImage,
        });
      } else {
        // For seekers, create account directly
        context.read<AuthBloc>().add(
              AuthSignUpRequested(
                email: _emailController.text.trim(),
                password: _passwordController.text,
                name: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                role: _selectedRole,
                profileImage: _profileImage,
              ),
            );
      }
    }
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm password is required';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            if (state.user.role == AppConstants.roleProvider) {
              context.go('/provider/home');
            } else {
              context.go('/seeker/home');
            }
          } else if (state is AuthPendingPhoneVerification) {
            // Signup pending, proceed to OTP step inside signup pipeline
            context.go('/phone-auth', extra: {
              'verificationId': state.verificationId,
              'phoneNumber': state.phoneNumber,
              'role': state.role,
              'isSignUpFlow': true,
              'pendingSignupData': state.pendingSignupData,
            });
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return CustomScrollView(
            slivers: [
              // Modern App Bar
              SliverAppBar(
                expandedHeight: 180,
                floating: true,
                pinned: true,
                backgroundColor: AppTheme.primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.08,
                            child: CustomPaint(
                              painter: WavePatternPainter(),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.person_add_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Join ${AppConstants.appName}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Create your account to get started',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.85),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, 
                        color: Colors.white, size: 18),
                  ),
                  onPressed: () => context.go('/login'),
                ),
              ),

              // Form Content
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Role Selection
                          Text(
                            'I want to:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildRoleCard(
                                  icon: Icons.search_rounded,
                                  title: 'Find Services',
                                  subtitle: 'Book vehicles & equipment',
                                  value: AppConstants.roleSeeker,
                                  isSelected: _selectedRole == AppConstants.roleSeeker,
                                  onTap: isLoading ? null : () {
                                    setState(() => _selectedRole = AppConstants.roleSeeker);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildRoleCard(
                                  icon: Icons.local_shipping_rounded,
                                  title: 'Offer Services',
                                  subtitle: 'Rent out your vehicles',
                                  value: AppConstants.roleProvider,
                                  isSelected: _selectedRole == AppConstants.roleProvider,
                                  onTap: isLoading ? null : () {
                                    setState(() => _selectedRole = AppConstants.roleProvider);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          
                          // Profile Picture Section
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: isLoading ? null : () async {
                                    final image = await CrossPlatformImagePicker.pickFromGallery();
                                    if (image?.bytes != null) {
                                      setState(() => _profileImage = image!.bytes);
                                    }
                                  },
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: _profileImage == null
                                          ? AppTheme.primaryGradient
                                          : null,
                                      border: Border.all(
                                        color: AppTheme.primaryColor,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: _profileImage == null
                                        ? Icon(
                                            Icons.add_a_photo_rounded,
                                            size: 40,
                                            color: Colors.white.withOpacity(0.9),
                                          )
                                        : ClipOval(
                                            child: Image.memory(
                                              _profileImage!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _profileImage == null ? 'Add Profile Photo' : 'Change Photo',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Required',
                                  style: TextStyle(
                                    color: AppTheme.errorColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          
                          // Personal Information Section
                          _buildSectionHeader(
                            icon: Icons.person_rounded,
                            title: 'Personal Information',
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 16),
                          
                          // Name Field
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            hint: 'Enter your full name',
                            icon: Icons.badge_rounded,
                            iconColor: AppTheme.primaryColor,
                            validator: (value) => Validators.required(value, fieldName: 'Name'),
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),
                          
                          // Email Field
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            hint: 'Enter your email',
                            icon: Icons.email_rounded,
                            iconColor: AppTheme.secondaryColor,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.email,
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),
                          
                          // Phone Field
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hint: '03001234567',
                            icon: Icons.phone_rounded,
                            iconColor: AppTheme.accentColor,
                            keyboardType: TextInputType.phone,
                            validator: Validators.phone,
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 24),
                          
                          // Security Section
                          _buildSectionHeader(
                            icon: Icons.security_rounded,
                            title: 'Security',
                            color: AppTheme.secondaryColor,
                          ),
                          const SizedBox(height: 16),
                          
                          // Password Field
                          _buildPasswordField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Create a strong password',
                            obscureText: _obscurePassword,
                            onToggle: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                            validator: Validators.password,
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),
                          
                          // Confirm Password
                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            obscureText: _obscureConfirmPassword,
                            onToggle: () {
                              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                            },
                            validator: _validateConfirmPassword,
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 32),
                          
                          // Sign Up Button
                          GradientButton(
                            text: 'Create Account',
                            icon: Icons.person_add_rounded,
                            isLoading: isLoading,
                            onPressed: isLoading ? null : _handleSignup,
                          ),
                          const SizedBox(height: 24),
                          
                          // Sign In Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                              GestureDetector(
                                onTap: isLoading ? null : () => context.go('/login'),
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryColor 
                : AppTheme.primaryColor.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : AppTheme.softShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.white.withOpacity(0.2) 
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected 
                    ? Colors.white.withOpacity(0.8) 
                    : AppTheme.textSecondary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
      ),
      validator: validator,
      enabled: enabled,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.lock_rounded,
            color: AppTheme.secondaryColor,
            size: 18,
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: AppTheme.textSecondary,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
      enabled: enabled,
    );
  }
}

/// Wave Pattern Painter
class WavePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    for (int i = 0; i < 4; i++) {
      path.moveTo(0, size.height * (0.3 + i * 0.15));
      for (double x = 0; x <= size.width; x += 1) {
        path.lineTo(
          x,
          size.height * (0.3 + i * 0.15) + 
              10 * (i + 1) * (0.5 - (x / size.width - 0.5).abs()),
        );
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
