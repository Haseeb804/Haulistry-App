import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/cross_platform_image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../widgets/dynamic_service_fields.dart';

class ProviderDocumentsScreen extends StatefulWidget {
  final Map<String, dynamic>? signupData;
  
  const ProviderDocumentsScreen({super.key, this.signupData});

  @override
  State<ProviderDocumentsScreen> createState() =>
      _ProviderDocumentsScreenState();
}

class _ProviderDocumentsScreenState extends State<ProviderDocumentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cnicController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleCapacityController = TextEditingController();
  String? _selectedVehicleType;

  Map<String, dynamic> _extraFieldValues = {};

  CrossPlatformImage? _cnicFrontImage;
  CrossPlatformImage? _cnicBackImage;
  CrossPlatformImage? _licenseImage;
  CrossPlatformImage? _vehicleImage;

  @override
  void dispose() {
    _cnicController.dispose();
    _vehicleNumberController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleCapacityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final image = await CrossPlatformImagePicker.pickFromGallery();
    if (image != null) {
      setState(() {
        switch (type) {
          case 'cnic_front':
            _cnicFrontImage = image;
            break;
          case 'cnic_back':
            _cnicBackImage = image;
            break;
          case 'license':
            _licenseImage = image;
            break;
          case 'vehicle':
            _vehicleImage = image;
            break;
        }
      });
    }
  }

  Future<void> _captureImage(String type) async {
    final image = await CrossPlatformImagePicker.takePhoto();
    if (image != null) {
      setState(() {
        switch (type) {
          case 'cnic_front':
            _cnicFrontImage = image;
            break;
          case 'cnic_back':
            _cnicBackImage = image;
            break;
          case 'license':
            _licenseImage = image;
            break;
          case 'vehicle':
            _vehicleImage = image;
            break;
        }
      });
    }
  }

  void _showImageSourceDialog(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.white),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(type);
                },
              ),
              if (!kIsWeb)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.secondaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                  ),
                  title: const Text('Take a Photo'),
                  subtitle: const Text('Use your camera'),
                  onTap: () {
                    Navigator.pop(context);
                    _captureImage(type);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSubmit() {

    
    if (!_formKey.currentState!.validate()) {

      return;
    }

    if (_selectedVehicleType == null || _selectedVehicleType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Please select a vehicle type')),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_cnicFrontImage == null || _cnicBackImage == null || _licenseImage == null || _vehicleImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Please upload all required documents')),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    final signupData = widget.signupData;
    
    // Convert images to Base64
    String? cnicFrontBase64;
    String? cnicBackBase64;
    String? licenseBase64;
    String? vehicleBase64;
    
    if (_cnicFrontImage?.bytes != null) {
      cnicFrontBase64 = base64Encode(_cnicFrontImage!.bytes);
    }
    if (_cnicBackImage?.bytes != null) {
      cnicBackBase64 = base64Encode(_cnicBackImage!.bytes);
    }
    if (_licenseImage?.bytes != null) {
      licenseBase64 = base64Encode(_licenseImage!.bytes);
    }
    if (_vehicleImage?.bytes != null) {
      vehicleBase64 = base64Encode(_vehicleImage!.bytes);
    }
    
    // If we have signup data, this is a new registration
    if (signupData != null) {
      context.read<AuthBloc>().add(
            AuthProviderSignUpWithDocuments(
              email: signupData['email'] as String,
              password: signupData['password'] as String,
              name: signupData['name'] as String,
              phone: signupData['phone'] as String,
              profileImage: signupData['profileImage'] as Uint8List?,
              cnic: _cnicController.text.trim(),
              vehicleNumber: _vehicleNumberController.text.trim(),
              vehicleType: _selectedVehicleType!,
              vehicleModel: _vehicleModelController.text.trim(),
              vehicleYear: _vehicleYearController.text.trim(),
              vehicleCapacity: double.tryParse(_vehicleCapacityController.text.trim()) ?? 0,
              cnicFrontImageBase64: cnicFrontBase64,
              cnicBackImageBase64: cnicBackBase64,
              licenseImageBase64: licenseBase64,
              vehicleImageBase64: vehicleBase64,
              vehicleExtraFields: _extraFieldValues.isNotEmpty
                  ? jsonEncode(_extraFieldValues)
                  : null,
            ),
          );
    } else if (authState is AuthAuthenticated) {
      // Existing user updating documents
      context.read<AuthBloc>().add(
            AuthDocumentsUploadRequested(
              userId: authState.user.id,
              cnicFrontImagePath: _cnicFrontImage!.path ?? _cnicFrontImage!.name,
              cnicBackImagePath: _cnicBackImage!.path ?? _cnicBackImage!.name,
              licenseImagePath: _licenseImage!.path ?? _licenseImage!.name,
              vehicleImagePath: _vehicleImage!.path ?? _vehicleImage!.name,
              cnic: _cnicController.text.trim(),
              vehicleNumber: _vehicleNumberController.text.trim(),
              vehicleType: _selectedVehicleType!,
              vehicleModel: _vehicleModelController.text.trim(),
              vehicleYear: _vehicleYearController.text.trim(),
              vehicleCapacity: double.tryParse(_vehicleCapacityController.text.trim()) ?? 0,
              cnicFrontImageBytes: _cnicFrontImage!.bytes,
              cnicBackImageBytes: _cnicBackImage!.bytes,
              licenseImageBytes: _licenseImage!.bytes,
              vehicleImageBytes: _vehicleImage!.bytes,
            ),
          );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete signup first'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthPendingPhoneVerification) {
            context.go('/phone-auth', extra: {
              'verificationId': state.verificationId,
              'phoneNumber': state.phoneNumber,
              'role': state.role,
              'isSignUpFlow': true,
              'pendingSignupData': state.pendingSignupData,
            });
          } else if (state is AuthAuthenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Account created successfully!'),
                  ],
                ),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            context.go('/provider/home');
          } else if (state is AuthDocumentsUploaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Documents uploaded successfully!'),
                  ],
                ),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            context.go('/provider/home');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                    onPressed: () {
                      // If new registration, go back to signup; otherwise go to home
                      if (widget.signupData != null) {
                        context.go('/signup');
                      } else {
                        context.go('/provider/home');
                      }
                    },
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: DocumentPatternPainter(color: Colors.white.withOpacity(0.05))),
                        ),
                        SafeArea(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 30),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.folder_open_rounded, size: 40, color: Colors.white),
                                ),
                                const SizedBox(height: 12),
                                const Text('Upload Documents', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppTheme.accentGradient.scale(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.accentGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.info_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Please upload clear photos of your documents for verification',
                                  style: TextStyle(color: AppTheme.accentColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // CNIC Section
                        _buildSectionTitle('CNIC (National ID Card)', Icons.badge_rounded),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactDocumentSection(
                                title: 'Front Side',
                                image: _cnicFrontImage,
                                onTap: () => _showImageSourceDialog('cnic_front'),
                                isRequired: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCompactDocumentSection(
                                title: 'Back Side',
                                image: _cnicBackImage,
                                onTap: () => _showImageSourceDialog('cnic_back'),
                                isRequired: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _cnicController,
                          label: 'CNIC Number',
                          hint: '12345-1234567-1',
                          icon: Icons.badge_rounded,
                          validator: Validators.cnic,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 24),

                        // Driving License Section
                        _buildSectionTitle('Driving License', Icons.credit_card_rounded),
                        const SizedBox(height: 12),
                        _buildDocumentSection(
                          title: 'License Photo',
                          image: _licenseImage,
                          onTap: () => _showImageSourceDialog('license'),
                          isRequired: true,
                        ),
                        const SizedBox(height: 24),

                        // Vehicle Section
                        _buildSectionTitle('Vehicle Information', Icons.local_shipping_rounded),
                        const SizedBox(height: 12),
                        _buildDocumentSection(
                          title: 'Vehicle Photo',
                          image: _vehicleImage,
                          onTap: () => _showImageSourceDialog('vehicle'),
                          isRequired: true,
                        ),
                        const SizedBox(height: 16),
                        
                        // Vehicle Type Dropdown
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedVehicleType,
                            decoration: InputDecoration(
                              labelText: 'Vehicle/Equipment Type *',
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.construction_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 18,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: AppConstants.serviceCategories
                                .map((cat) => DropdownMenuItem(
                                      value: cat.value,
                                      child: Text('${cat.emoji} ${cat.label}'),
                                    ))
                                .toList(),
                            onChanged: isLoading ? null : (value) {
                              setState(() {
                                _selectedVehicleType = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a vehicle type';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_selectedVehicleType != null)
                          DynamicServiceFields(
                            key: ValueKey(_selectedVehicleType),
                            category: _selectedVehicleType!,
                            initialValues: const {},
                            onChanged: (values) {
                              setState(() {
                                _extraFieldValues = values;
                              });
                            },
                          ),

                        if (_selectedVehicleType != null)
                          const SizedBox(height: 16),

                        _buildModernTextField(
                          controller: _vehicleNumberController,
                          label: 'Vehicle Number *',
                          hint: 'ABC-1234',
                          icon: Icons.numbers_rounded,
                          textCapitalization: TextCapitalization.characters,
                          validator: Validators.vehicleNumber,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),
                        
                        _buildModernTextField(
                          controller: _vehicleModelController,
                          label: 'Vehicle Model *',
                          hint: 'e.g., Hino, Isuzu, Massey',
                          icon: Icons.directions_car_rounded,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vehicle model is required';
                            }
                            return null;
                          },
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildModernTextField(
                                controller: _vehicleYearController,
                                label: 'Year *',
                                hint: '2020',
                                icon: Icons.calendar_month_rounded,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Year required';
                                  }
                                  return null;
                                },
                                enabled: !isLoading,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildModernTextField(
                                controller: _vehicleCapacityController,
                                label: 'Capacity (Tons) *',
                                hint: '5',
                                icon: Icons.scale_rounded,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Capacity required';
                                  }
                                  return null;
                                },
                                enabled: !isLoading,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        GradientButton(
                          text: isLoading ? 'Uploading...' : 'Submit for Verification',
                          icon: Icons.upload_rounded,
                          gradient: AppTheme.accentGradient,
                          onPressed: isLoading ? null : _handleSubmit,
                        ),
                        const SizedBox(height: 16),

                        // Info text instead of skip
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: AppTheme.warningColor, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'All fields are required to start receiving bookings',
                                  style: TextStyle(color: AppTheme.warningColor, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool enabled = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        validator: validator,
        enabled: enabled,
      ),
    );
  }

  Widget _buildDocumentSection({
    required String title,
    required CrossPlatformImage? image,
    required VoidCallback onTap,
    required bool isRequired,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.softShadow,
          border: image != null
              ? Border.all(color: AppTheme.successColor, width: 2)
              : Border.all(color: Colors.grey.shade200),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(image.bytes, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppTheme.secondaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Uploaded', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.add_photo_alternate_rounded, size: 40, color: AppTheme.accentColor),
                  ),
                  const SizedBox(height: 12),
                  Text('Tap to upload $title', style: const TextStyle(color: AppTheme.textSecondary)),
                  if (isRequired)
                    const Text('Required', style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                ],
              ),
      ),
    );
  }

  Widget _buildCompactDocumentSection({
    required String title,
    required CrossPlatformImage? image,
    required VoidCallback onTap,
    required bool isRequired,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.softShadow,
          border: image != null
              ? Border.all(color: AppTheme.successColor, width: 2)
              : Border.all(color: Colors.grey.shade200),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(image.bytes, fit: BoxFit.cover),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AppTheme.secondaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 2),
                            Text('OK', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_photo_alternate_rounded, size: 28, color: AppTheme.accentColor),
                  ),
                  const SizedBox(height: 8),
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  if (isRequired)
                    const Text('Required', style: TextStyle(color: AppTheme.errorColor, fontSize: 10)),
                ],
              ),
      ),
    );
  }
}

class DocumentPatternPainter extends CustomPainter {
  final Color color;
  DocumentPatternPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    for (double i = 0; i < size.width; i += 30) {
      for (double j = 0; j < size.height; j += 30) {
        canvas.drawCircle(Offset(i, j), 2, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
