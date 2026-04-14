import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/provider_bloc.dart';
import '../bloc/provider_event.dart';
import '../bloc/provider_state.dart';

class ProviderRequestReviewScreen extends StatefulWidget {
  final String bookingId;

  const ProviderRequestReviewScreen({super.key, required this.bookingId});

  @override
  State<ProviderRequestReviewScreen> createState() => _ProviderRequestReviewScreenState();
}

class _ProviderRequestReviewScreenState extends State<ProviderRequestReviewScreen> {
  BookingEntity? _booking;
  final TextEditingController _rejectReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ProviderBloc>().add(const ProviderLoadBookingsRequested());
  }

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  void _accept() {
    context.read<ProviderBloc>().add(
          ProviderAcceptBookingRequested(bookingId: widget.bookingId),
        );
  }

  void _reject() {
    final reason = _rejectReasonController.text.trim();
    context.read<ProviderBloc>().add(
          ProviderRejectBookingRequested(
            bookingId: widget.bookingId,
            reason: reason.isEmpty ? 'Provider unavailable' : reason,
          ),
        );
  }

  void _openTracking(BookingEntity booking) {
    context.go(
      '/provider/tracking/${booking.id}',
      extra: {
        'pickupLocation': LatLng(booking.pickupLatitude, booking.pickupLongitude),
        'dropoffLocation': LatLng(booking.dropLatitude, booking.dropLongitude),
        'pickupAddress': booking.pickupAddress,
        'dropAddress': booking.dropAddress,
        'estimatedPrice': booking.estimatedPrice,
        'serviceType': booking.serviceType,
        'bookingStatus': booking.status,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProviderBloc, ProviderState>(
      listener: (context, state) {
        if (state is ProviderBookingActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: state.action == 'accept'
                  ? AppTheme.primaryColor
                  : AppTheme.errorColor,
            ),
          );

          if (state.action == 'accept' && state.acceptedBooking != null) {
            _openTracking(state.acceptedBooking!);
          } else if (state.action == 'reject') {
            context.go('/provider/home');
          }
        } else if (state is ProviderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is ProviderLoaded) {
          _booking = [...state.pendingBookings, ...state.activeBookings, ...state.completedBookings]
              .cast<BookingEntity?>()
              .firstWhere((b) => b?.id == widget.bookingId, orElse: () => null);
        }

        final isLoading = state is ProviderBookingActionInProgress &&
            state.bookingId == widget.bookingId;

        final booking = _booking;
        if (booking == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text('Review Request'),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                        child: const Icon(Icons.person_rounded, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.seekerName ?? 'Customer',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Service request received',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  title: 'Request Details',
                  child: Column(
                    children: [
                      _row('Service', booking.serviceType),
                      const Divider(height: 22),
                      _row('Pickup', booking.pickupAddress),
                      const Divider(height: 22),
                      _row('Destination', booking.dropAddress),
                      const Divider(height: 22),
                      _row('Estimated Fare', 'Rs ${booking.estimatedPrice.toStringAsFixed(0)}'),
                      const Divider(height: 22),
                      _row('Scheduled', booking.scheduledDateTime.toString()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  title: 'Provider Action',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _rejectReasonController,
                        enabled: !isLoading,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Reject reason (optional)',
                          hintText: 'Add a short reason if rejecting...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isLoading ? null : _reject,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                                side: const BorderSide(color: AppTheme.errorColor),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : _accept,
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded),
                              label: Text(isLoading ? 'Working...' : 'Accept'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => context.go('/provider/home'),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Back to Dashboard'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _row(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
  }
}