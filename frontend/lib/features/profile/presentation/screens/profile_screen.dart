import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../provider/presentation/bloc/provider_bloc.dart';
import '../../../provider/presentation/bloc/provider_event.dart';
import '../../../provider/presentation/bloc/provider_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Load vehicles when profile screen opens for providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.user.role == 'provider') {
        context.read<ProviderBloc>().add(const ProviderLoadVehiclesRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) {
            return Center(
              child: EmptyStateWidget(
                icon: Icons.lock_rounded,
                title: 'Not Authenticated',
                subtitle: 'Please login to view your profile',
              ),
            );
          }

          final user = state.user;
          final isProvider = user.role == 'provider';

          return CustomScrollView(
            slivers: [
              // Modern App Bar with Profile Header
              SliverAppBar(
                expandedHeight: 280,
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
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      onPressed: () => context.push('/profile/edit'),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: isProvider ? AppTheme.primaryGradient : AppTheme.secondaryGradient,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(32),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Background pattern
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ProfilePatternPainter(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        // Profile content
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 50, 20, 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Profile Picture with border
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.white,
                                    child: user.profileImageUrl != null
                                        ? ClipOval(
                                            child: ImageHelper.imageWidget(
                                              imageUrl: user.profileImageUrl!,
                                              width: 80,
                                              height: 80,
                                            ),
                                          )
                                        : Text(
                                            user.name[0].toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: isProvider
                                                  ? AppTheme.primaryColor
                                                  : AppTheme.secondaryColor,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                
                                // Name
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                
                                // Role Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isProvider
                                            ? Icons.handyman_rounded
                                            : Icons.person_search_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isProvider ? 'Provider' : 'Seeker',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Provider Rating
                                if (isProvider && user.rating != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ...List.generate(5, (index) {
                                        return Icon(
                                          index < user.rating!.round()
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          color: Colors.amber,
                                          size: 16,
                                        );
                                      }),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${user.rating!.toStringAsFixed(1)} • ${user.completedBookings ?? 0} jobs',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Profile Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contact Info Section
                      _buildSectionHeader(
                        icon: Icons.contact_mail_rounded,
                        title: 'Contact Information',
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 12),
                      _buildModernInfoCard(
                        icon: Icons.email_rounded,
                        title: 'Email',
                        value: user.email,
                        gradient: AppTheme.primaryGradient,
                      ),
                      const SizedBox(height: 12),
                      _buildModernInfoCard(
                        icon: Icons.phone_rounded,
                        title: 'Phone',
                        value: user.phone,
                        gradient: AppTheme.secondaryGradient,
                      ),
                      if (user.address != null) ...[
                        const SizedBox(height: 12),
                        _buildModernInfoCard(
                          icon: Icons.location_on_rounded,
                          title: 'Address',
                          value: user.address!,
                          gradient: AppTheme.accentGradient,
                        ),
                      ],
                      
                      // Provider specific info
                      if (isProvider) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          icon: Icons.badge_rounded,
                          title: 'Verification Documents',
                          color: AppTheme.secondaryColor,
                        ),
                        const SizedBox(height: 12),
                        if (user.cnic != null)
                          _buildModernInfoCard(
                            icon: Icons.credit_card_rounded,
                            title: 'CNIC',
                            value: user.cnic!,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF636e72), Color(0xFF2d3436)],
                            ),
                          ),
                        if (user.drivingLicense != null) ...[
                          const SizedBox(height: 12),
                          _buildModernInfoCard(
                            icon: Icons.drive_eta_rounded,
                            title: 'Driving License',
                            value: user.drivingLicense!,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0984e3), Color(0xFF74b9ff)],
                            ),
                          ),
                        ],
                        
                        // My Vehicle Section
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          icon: Icons.local_shipping_rounded,
                          title: 'My Vehicle',
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 12),
                        _buildVehicleSection(context),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Verification Status
                      _buildVerificationCard(
                        isVerified: user.isVerified,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Quick Actions Section
                      _buildSectionHeader(
                        icon: Icons.flash_on_rounded,
                        title: 'Quick Actions',
                        color: AppTheme.accentColor,
                      ),
                      const SizedBox(height: 12),
                      
                      if (isProvider) ...[
                        _buildActionCard(
                          icon: Icons.handyman_rounded,
                          title: 'Manage Services',
                          subtitle: 'Add, edit or remove your services',
                          gradient: AppTheme.primaryGradient,
                          onTap: () => context.push('/provider/services'),
                        ),
                        const SizedBox(height: 12),
                        _buildActionCard(
                          icon: Icons.local_shipping_rounded,
                          title: 'View Vehicles',
                          subtitle: 'Manage your registered vehicles',
                          gradient: AppTheme.secondaryGradient,
                          onTap: () => context.push('/provider/vehicles'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      _buildActionCard(
                        icon: Icons.history_rounded,
                        title: 'Booking History',
                        subtitle: 'View all your past bookings',
                        gradient: AppTheme.accentGradient,
                        onTap: () {
                          if (isProvider) {
                            context.push('/provider/history');
                          } else {
                            context.push('/seeker/history');
                          }
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Logout Button
                      GestureDetector(
                        onTap: () => _showLogoutDialog(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.errorColor.withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                              SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  color: AppTheme.errorColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildModernInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard({required bool isVerified}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isVerified
            ? const LinearGradient(
                colors: [Color(0xFFd4edda), Color(0xFFc3e6cb)],
              )
            : const LinearGradient(
                colors: [Color(0xFFfff3cd), Color(0xFFffeeba)],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.warningColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isVerified ? Icons.verified_rounded : Icons.pending_rounded,
              color: isVerified ? AppTheme.successColor : AppTheme.warningColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verification Status',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isVerified ? 'Verified ✓' : 'Pending Verification',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isVerified
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                ),
              ],
            ),
          ),
          if (isVerified)
            const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.successColor,
              size: 32,
            )
          else
            const Icon(
              Icons.access_time_rounded,
              color: AppTheme.warningColor,
              size: 32,
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softShadow,
          ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppTheme.textSecondary,
                size: 16,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildVehicleSection(BuildContext context) {
    return BlocBuilder<ProviderBloc, ProviderState>(
      builder: (context, state) {
        if (state is ProviderLoading) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.softShadow,
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        if (state is ProviderLoaded && state.vehicles.isNotEmpty) {
          final vehicle = state.vehicles.first;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Image
                if (vehicle.vehicleImageBase64 != null && vehicle.vehicleImageBase64!.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.memory(
                      base64Decode(vehicle.vehicleImageBase64!),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        child: const Center(
                          child: Icon(Icons.local_shipping_rounded, size: 50, color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: const Center(
                      child: Icon(Icons.local_shipping_rounded, size: 50, color: AppTheme.primaryColor),
                    ),
                  ),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vehicle Type
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              vehicle.vehicleType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: vehicle.isAvailable
                                  ? AppTheme.successColor.withOpacity(0.1)
                                  : AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: vehicle.isAvailable
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  vehicle.isAvailable ? 'Available' : 'Unavailable',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: vehicle.isAvailable
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Vehicle Number
                      _buildVehicleInfoRow(
                        icon: Icons.confirmation_number_rounded,
                        label: 'Number',
                        value: vehicle.vehicleNumber,
                      ),
                      
                      // Vehicle Model
                      if (vehicle.vehicleModel != null && vehicle.vehicleModel!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildVehicleInfoRow(
                          icon: Icons.directions_car_rounded,
                          label: 'Model',
                          value: vehicle.vehicleModel!,
                        ),
                      ],
                      
                      // Vehicle Year
                      if (vehicle.vehicleYear != null && vehicle.vehicleYear!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildVehicleInfoRow(
                          icon: Icons.calendar_month_rounded,
                          label: 'Year',
                          value: vehicle.vehicleYear!,
                        ),
                      ],
                      
                      // Capacity
                      if (vehicle.capacity != null) ...[
                        const SizedBox(height: 8),
                        _buildVehicleInfoRow(
                          icon: Icons.scale_rounded,
                          label: 'Capacity',
                          value: '${vehicle.capacity!.toStringAsFixed(1)} tons',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // No vehicle found
        return GestureDetector(
          onTap: () => context.push('/provider/vehicles'),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.softShadow,
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No Vehicle Added',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap to add your first vehicle',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(const AuthSignOutRequested());
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// Pattern painter for profile header
class ProfilePatternPainter extends CustomPainter {
  final Color color;

  ProfilePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw circles pattern
    for (double i = 0; i < size.width; i += 60) {
      for (double j = 0; j < size.height; j += 60) {
        canvas.drawCircle(Offset(i, j), 4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
