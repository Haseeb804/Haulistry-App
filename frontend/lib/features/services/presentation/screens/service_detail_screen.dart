import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class ServiceDetailScreen extends StatelessWidget {
  final String serviceType;

  const ServiceDetailScreen({
    super.key,
    required this.serviceType,
  });

  @override
  Widget build(BuildContext context) {
    final baseRate = AppConstants.baseRates[serviceType] ?? 0.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
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
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  onPressed: () {
                    // TODO: Implement share functionality
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ServicePatternPainter(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                _getServiceIcon(serviceType),
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              serviceType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating & Availability Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFC107), Color(0xFFFFD54F)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 4),
                            Text(
                              '4.8',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.successColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '15 providers available',
                              style: TextStyle(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pricing Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Pricing',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildPricingRow(
                          context,
                          'Base Rate',
                          'Rs. ${baseRate.toStringAsFixed(0)}',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(),
                        ),
                        _buildPricingRow(
                          context,
                          'Per KM',
                          'Rs. ${AppConstants.pricePerKm.toStringAsFixed(0)}',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(),
                        ),
                        _buildPricingRow(
                          context,
                          'Minimum Charge',
                          'Rs. ${AppConstants.minimumCharge.toStringAsFixed(0)}',
                          isHighlighted: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  const Row(
                    children: [
                      Icon(Icons.info_rounded, color: AppTheme.primaryColor, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'About this service',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getServiceDescription(serviceType),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Features
                  const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: AppTheme.secondaryColor, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Features',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem('Real-time GPS tracking', Icons.gps_fixed_rounded),
                  _buildFeatureItem('Verified providers', Icons.verified_user_rounded),
                  _buildFeatureItem('Secure payment', Icons.security_rounded),
                  _buildFeatureItem('24/7 support', Icons.support_agent_rounded),
                  _buildFeatureItem('Insurance coverage', Icons.shield_rounded),
                  const SizedBox(height: 24),

                  // Similar Services
                  const Row(
                    children: [
                      Icon(Icons.category_rounded, color: AppTheme.accentColor, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Similar Services',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: AppConstants.serviceTypes.length,
                      itemBuilder: (context, index) {
                        final service = AppConstants.serviceTypes[index];
                        if (service == serviceType) return const SizedBox();
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              context.pushReplacement('/service/$service');
                            },
                            child: Container(
                              width: 100,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient.scale(0.3),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getServiceIcon(service),
                                      size: 28,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      service,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: GradientButton(
          text: 'Book Now',
          icon: Icons.calendar_today_rounded,
          gradient: AppTheme.primaryGradient,
          onPressed: () {
            final authState = context.read<AuthBloc>().state;
            if (authState is! AuthAuthenticated) {
              context.push('/login');
              return;
            }
            context.push('/booking/create', extra: {'serviceType': serviceType});
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildPricingRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlighted ? 16 : 14,
            color: isHighlighted ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isHighlighted ? 14 : 10,
            vertical: isHighlighted ? 8 : 6,
          ),
          decoration: BoxDecoration(
            gradient: isHighlighted ? AppTheme.primaryGradient : null,
            color: isHighlighted ? null : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: isHighlighted ? 16 : 14,
              color: isHighlighted ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String feature, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.secondaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              feature,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getServiceIcon(String service) {
    switch (service) {
      case 'Sand Trolley':
        return Icons.local_shipping;
      case 'Bricks Trolley':
        return Icons.fire_truck;
      case 'Harvester':
        return Icons.agriculture;
      case 'Crane':
        return Icons.construction;
      case 'Dumper':
        return Icons.directions_bus;
      case 'Excavator':
        return Icons.engineering;
      case 'Tractor':
        return Icons.departure_board;
      case 'Water Tanker':
        return Icons.water_drop;
      default:
        return Icons.build;
    }
  }

  String _getServiceDescription(String service) {
    switch (service) {
      case 'Sand Trolley':
        return 'Professional sand transportation service for construction sites. Our verified providers ensure timely delivery with quality sand for all your construction needs. Perfect for residential and commercial projects.';
      case 'Bricks Trolley':
        return 'Reliable brick transportation service with experienced drivers. We handle your construction materials with care, ensuring safe delivery to your site. Ideal for building projects of any scale.';
      case 'Harvester':
        return 'Modern harvesting equipment with skilled operators for efficient crop harvesting. Save time and labor costs with our professional harvesting services. Suitable for wheat, rice, and other crops.';
      case 'Crane':
        return 'Heavy-duty crane services for construction and industrial projects. Our certified operators ensure safe lifting and placement of heavy materials. Available in various capacities.';
      case 'Dumper':
        return 'Heavy-duty dumper trucks for transporting construction materials, debris, and excavated earth. Perfect for large-scale construction and infrastructure projects.';
      case 'Excavator':
        return 'Professional excavation services for digging, trenching, and earth moving. Our experienced operators handle projects of all sizes with precision and efficiency.';
      case 'Tractor':
        return 'Versatile tractor services for agricultural and construction tasks. From plowing fields to material transport, our tractors handle diverse requirements.';
      case 'Water Tanker':
        return 'Clean water delivery service for construction sites, events, and residential areas. Our tankers ensure hygienic water transportation with timely delivery.';
      default:
        return 'Professional service with verified providers. Book now for reliable and timely service delivery.';
    }
  }
}

// Pattern painter
class ServicePatternPainter extends CustomPainter {
  final Color color;
  ServicePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double i = 0; i < size.width; i += 35) {
      for (double j = 0; j < size.height; j += 35) {
        canvas.drawCircle(Offset(i, j), 2.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
