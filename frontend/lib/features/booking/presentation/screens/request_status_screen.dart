import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../feedback/data/datasources/feedback_remote_datasource.dart';
import '../../../feedback/data/repositories/feedback_repository_impl.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';

class RequestStatusScreen extends StatefulWidget {
  final String bookingId;

  const RequestStatusScreen({
    super.key,
    required this.bookingId,
  });

  @override
  State<RequestStatusScreen> createState() => _RequestStatusScreenState();
}

class _RequestStatusScreenState extends State<RequestStatusScreen> {
  final FeedbackRepositoryImpl _feedbackRepository = FeedbackRepositoryImpl(
    remoteDataSource: FeedbackRemoteDataSource(baseUrl: AppConstants.apiUrl),
  );

  Timer? _pollingTimer;
  BookingEntity? _booking;
  bool _routingFeedback = false;
  bool _routingTracking = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadStatus());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _loadStatus() {
    context.read<BookingBloc>().add(LoadBookingRequested(bookingId: widget.bookingId));
  }

  BookingEntity? _extractBooking(BookingState state) {
    if (state is BookingTracking) return state.booking;
    if (state is ProviderArrivingState) return state.booking;
    if (state is ProviderArrivedState) return state.booking;
    if (state is BookingInProgressState) return state.booking;
    if (state is BookingCompletedState) return state.booking;
    if (state is BookingCancelledState) return state.booking;
    return null;
  }

  bool _isAccepted(String status) {
    final s = status.toLowerCase();
    return s == AppConstants.statusAccepted ||
        s == AppConstants.statusActive ||
        s == AppConstants.statusProviderArriving ||
        s == AppConstants.statusProviderArrived ||
        s == AppConstants.statusInProgress;
  }

  bool _isRejected(String status) {
    final s = status.toLowerCase();
    return s == AppConstants.statusRejected || s == AppConstants.statusCancelled;
  }

  bool _isCompleted(String status) => status.toLowerCase() == AppConstants.statusCompleted;

  String _prettyStatus(String status) {
    return status
        .split('_')
        .map((part) => part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  Future<void> _routeToSeekerFeedback(BookingEntity booking) async {
    if (_routingFeedback || !mounted) return;
    _routingFeedback = true;

    try {
      final exists = await _feedbackRepository.checkFeedbackExists(booking.id, AppConstants.roleSeeker);
      if (!mounted || exists) return;

      context.go(AppRoutes.feedbackSeeker, extra: {
        'bookingId': booking.id,
        'providerId': booking.providerId ?? '',
        'providerName': booking.providerName ?? 'Provider',
      });
    } catch (_) {
      // Keep screen usable on transient errors.
    }
  }

  void _routeToTracking(BookingEntity booking) {
    if (_routingTracking || !mounted) return;
    _routingTracking = true;

    context.go(AppConstants.seekerTrackingPath(booking.id), extra: {
      'providerId': booking.providerId ?? '',
      'providerName': booking.providerName,
      'pickupLocation': LatLng(booking.pickupLatitude, booking.pickupLongitude),
      'dropoffLocation': LatLng(booking.dropLatitude, booking.dropLongitude),
      'pickupAddress': booking.pickupAddress,
      'dropAddress': booking.dropAddress,
      'estimatedPrice': booking.estimatedPrice,
      'serviceType': booking.serviceType,
      'bookingStatus': booking.status,
    });
  }

  void _openAcceptedScreen(BookingEntity booking) {
    context.go(AppConstants.seekerAcceptedPath(booking.id), extra: {
      'providerId': booking.providerId ?? '',
      'providerName': booking.providerName,
      'pickupLocation': LatLng(booking.pickupLatitude, booking.pickupLongitude),
      'dropoffLocation': LatLng(booking.dropLatitude, booking.dropLongitude),
      'pickupAddress': booking.pickupAddress,
      'dropAddress': booking.dropAddress,
      'estimatedPrice': booking.estimatedPrice,
      'serviceType': booking.serviceType,
      'bookingStatus': booking.status,
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Request Status'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        body: BlocConsumer<BookingBloc, BookingState>(
          listener: (context, state) {
            final booking = _extractBooking(state);
            if (booking != null) {
              setState(() => _booking = booking);
              if (_isAccepted(booking.status)) {
                _routeToTracking(booking);
                return;
              }
              if (_isCompleted(booking.status)) {
                _routeToSeekerFeedback(booking);
              }
            }
          },
          builder: (context, state) {
            final booking = _booking;

            if (booking == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final status = booking.status;
            final accepted = _isAccepted(status);
            final rejected = _isRejected(status);

            return Padding(
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accepted
                                ? AppTheme.primaryColor.withValues(alpha: 0.12)
                                : rejected
                                    ? AppTheme.errorColor.withValues(alpha: 0.12)
                                    : AppTheme.warningColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            accepted
                                ? Icons.check_circle_rounded
                                : rejected
                                    ? Icons.cancel_rounded
                                    : Icons.hourglass_top_rounded,
                            color: accepted
                                ? AppTheme.primaryColor
                                : rejected
                                    ? AppTheme.errorColor
                                    : AppTheme.warningColor,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                accepted
                                    ? 'Request Accepted'
                                    : rejected
                                        ? 'Request Rejected'
                                        : 'Waiting for Provider',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Status: ${_prettyStatus(status)}',
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('Service', booking.serviceType),
                        const Divider(height: 22),
                        _infoRow('Provider', booking.providerName ?? 'Awaiting assignment'),
                        const Divider(height: 22),
                        _infoRow('Pickup', booking.pickupAddress),
                        const Divider(height: 22),
                        _infoRow('Destination', booking.dropAddress),
                        const Divider(height: 22),
                        _infoRow('Fare', 'Rs ${booking.estimatedPrice.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                  if (rejected) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Unfortunately your request was rejected by the provider. Please try another request.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (accepted)
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () => _routeToTracking(booking),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Open Live Tracking'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go(AppRoutes.seekerHome),
                        icon: const Icon(Icons.home_rounded),
                        label: Text(rejected ? 'Back to Dashboard' : 'Return to Dashboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _loadStatus,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh Status'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            title,
            style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
