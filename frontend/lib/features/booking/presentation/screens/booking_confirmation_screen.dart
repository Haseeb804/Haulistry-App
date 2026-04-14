import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import '../../domain/services/booking_service.dart';

class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({super.key});

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  bool _termsAccepted = false;
  final _bookingService = BookingService();

  void _submitBooking() {
    if (!_termsAccepted) {
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
              const Text('Please accept the terms and conditions'),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    context.read<BookingBloc>().add(const BookingSubmitRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: BlocConsumer<BookingBloc, BookingState>(
        listener: (context, state) {
          if (state is BookingSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Request submitted. Checking provider response...'),
                backgroundColor: AppTheme.successColor,
              ),
            );

            context.read<BookingBloc>().add(const BookingReset());
            context.go('/booking/${state.bookingId}/status');
          } else if (state is BookingError) {
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
          if (state is BookingSubmitting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  const Text('Creating your booking...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }

          final bookingState = state is BookingInProgress
              ? state
              : state is BookingError && state.currentState != null
                  ? state.currentState!
                  : null;

          if (bookingState == null || !bookingState.isReadyForSubmission) {
            // Booking state was reset (likely after successful submission and viewing offers)
            // Redirect user to home instead of showing error
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.go('/seeker/home');
              }
            });
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final priceBreakdown = _bookingService.getPriceBreakdown(
            serviceType: bookingState.serviceType!,
            distance: bookingState.distance!,
            totalPrice: bookingState.estimatedPrice!,
          );

          final travelTime = _bookingService.estimateTravelTime(
            bookingState.distance!,
          );

          return CustomScrollView(
            slivers: [
              // Modern App Bar
              SliverAppBar(
                expandedHeight: 200,
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
                    onPressed: () => context.pop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: ConfirmPatternPainter(color: Colors.white.withOpacity(0.05))),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 50, bottom: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.check_circle_outline_rounded, size: 36, color: Colors.white),
                                ),
                                const SizedBox(height: 10),
                                const Text('Review Your Booking', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
                      // Service Details
                      _buildSectionTitle('Service Details', Icons.local_shipping_rounded),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              icon: Icons.category_rounded,
                              label: 'Service',
                              value: bookingState.serviceType!,
                              gradient: AppTheme.primaryGradient,
                            ),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                            _buildDetailRow(
                              icon: Icons.calendar_today_rounded,
                              label: 'Scheduled',
                              value: DateFormat('MMM dd, yyyy - hh:mm a').format(bookingState.scheduledDateTime!),
                              gradient: AppTheme.accentGradient,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Location Details
                      _buildSectionTitle('Location Details', Icons.location_on_rounded),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          children: [
                            _buildLocationRow(
                              icon: Icons.my_location_rounded,
                              label: 'Pickup',
                              address: bookingState.pickupAddress!,
                              gradient: AppTheme.secondaryGradient,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  SizedBox(width: 20),
                                  Icon(Icons.arrow_downward_rounded, size: 20, color: AppTheme.textSecondary),
                                ],
                              ),
                            ),
                            _buildLocationRow(
                              icon: Icons.location_on_rounded,
                              label: 'Drop',
                              address: bookingState.dropAddress!,
                              gradient: AppTheme.primaryGradient,
                            ),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.straighten_rounded,
                                    label: 'Distance',
                                    value: '${bookingState.distance!.toStringAsFixed(1)} km',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.access_time_rounded,
                                    label: 'Est. Time',
                                    value: '$travelTime mins',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Price Breakdown
                      _buildSectionTitle('Price Breakdown', Icons.payments_rounded),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          children: [
                            _buildPriceRow('Base Rate', priceBreakdown['baseRate']!),
                            const SizedBox(height: 12),
                            _buildPriceRow(
                              'Distance (${bookingState.distance!.toStringAsFixed(1)} km × Rs. ${AppConstants.pricePerKm})',
                              priceBreakdown['distanceCost']!,
                            ),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                                  ),
                                  child: Text(
                                    'Rs. ${bookingState.estimatedPrice!.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Additional Notes
                      if (bookingState.notes != null && bookingState.notes!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle('Additional Notes', Icons.note_rounded),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppTheme.softShadow,
                          ),
                          child: Text(bookingState.notes!, style: const TextStyle(color: AppTheme.textSecondary)),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Terms and Conditions
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: CheckboxListTile(
                          value: _termsAccepted,
                          onChanged: (value) => setState(() => _termsAccepted = value ?? false),
                          title: const Text('I accept the terms and conditions'),
                          subtitle: TextButton(
                            onPressed: () {},
                            child: const Text('Read terms'),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          activeColor: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Confirm Button
                      GradientButton(
                        text: 'Confirm & Book',
                        icon: Icons.check_circle_rounded,
                        gradient: AppTheme.primaryGradient,
                        onPressed: _termsAccepted ? _submitBooking : null,
                      ),
                      const SizedBox(height: 12),

                      // Cancel Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: const Text('Go Back'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(color: Colors.grey.shade300, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required LinearGradient gradient,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required String address,
    required LinearGradient gradient,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(address, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
        Text('Rs. ${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class ConfirmPatternPainter extends CustomPainter {
  final Color color;
  ConfirmPatternPainter({required this.color});
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
