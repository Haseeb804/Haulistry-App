import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../bloc/provider_bloc.dart';
import '../bloc/provider_event.dart';
import '../bloc/provider_state.dart';

class ProviderBookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const ProviderBookingDetailScreen({super.key, required this.bookingId});

  @override
  State<ProviderBookingDetailScreen> createState() => _ProviderBookingDetailScreenState();
}

class _ProviderBookingDetailScreenState extends State<ProviderBookingDetailScreen> {
  StreamSubscription<Position>? _positionSubscription;
  BookingEntity? _booking;
  bool _isNearDropLocation = false;
  static const double _completionRadiusMeters = 100; // Auto-complete when within 100m of drop location

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    // Start listening to location updates
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen(_onLocationUpdate);
  }

  void _onLocationUpdate(Position position) {
    if (_booking == null) return;

    // Calculate distance to drop location
    final distanceToDropM = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _booking!.dropLatitude,
      _booking!.dropLongitude,
    );

    final wasNear = _isNearDropLocation;
    _isNearDropLocation = distanceToDropM <= _completionRadiusMeters;

    if (_isNearDropLocation && !wasNear && _booking!.status == 'in_progress') {
      // Provider has reached drop location - show auto-complete dialog
      _showAutoCompleteDialog();
    }

    if (mounted) setState(() {});
  }

  void _showAutoCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('You\'ve Arrived!'),
        content: const Text(
          'You have reached the drop-off location. Would you like to mark this booking as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _completeBooking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text('Complete Booking'),
          ),
        ],
      ),
    );
  }

  void _completeBooking() {
    context.read<ProviderBloc>().add(
      ProviderCompleteBookingRequested(bookingId: widget.bookingId),
    );
  }

  void _navigateToTracking() {
    if (_booking == null) return;
    context.push(
      '/provider/tracking/${widget.bookingId}',
      extra: {
        'pickupLocation': LatLng(_booking!.pickupLatitude, _booking!.pickupLongitude),
        'dropoffLocation': LatLng(_booking!.dropLatitude, _booking!.dropLongitude),
        'pickupAddress': _booking!.pickupAddress,
        'dropAddress': _booking!.dropAddress,
        'estimatedPrice': _booking!.estimatedPrice,
        'serviceType': _booking!.serviceType,
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
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(state.message),
                ],
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
          // Navigate back after completion
          context.pop();
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
        // Find the booking from loaded state
        if (state is ProviderLoaded) {
          _booking = [...state.activeBookings, ...state.pendingBookings, ...state.completedBookings]
              .cast<BookingEntity?>()
              .firstWhere(
                (b) => b?.id == widget.bookingId,
                orElse: () => null,
              );
        }

        final isLoading = state is ProviderBookingActionInProgress &&
            state.bookingId == widget.bookingId;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Booking Details'),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          body: _booking == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      _buildStatusCard(),
                      const SizedBox(height: 16),

                      // Location Details
                      _buildLocationCard(),
                      const SizedBox(height: 16),

                      // Booking Info
                      _buildInfoCard(),
                      const SizedBox(height: 24),

                      // Track Button
                      if (_booking!.status == 'in_progress' ||
                          _booking!.status == 'provider_arrived' ||
                          _booking!.status == 'accepted' ||
                          _booking!.status == 'provider_arriving')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () => _navigateToTracking(),
                              icon: const Icon(Icons.map_rounded),
                              label: const Text(
                                'Track on Map',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Location Proximity Indicator
                      if (_booking!.status == 'in_progress') ...[
                        _buildProximityIndicator(),
                        const SizedBox(height: 16),
                      ],

                      // Complete Button
                      if (_booking!.status == 'in_progress' ||
                          _booking!.status == 'provider_arrived')
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : _completeBooking,
                            icon: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_rounded),
                            label: Text(
                              isLoading ? 'Completing...' : 'Complete Booking',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStatusCard() {
    final statusColor = _getStatusColor(_booking!.status);
    final statusText = _getStatusText(_booking!.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStatusIcon(_booking!.status),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                Text(
                  _booking!.serviceType.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Rs. ${_booking!.estimatedPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.trip_origin,
            color: AppTheme.successColor,
            title: 'Pickup',
            address: _booking!.pickupAddress,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Divider(height: 24),
          ),
          _buildLocationRow(
            icon: Icons.location_on,
            color: AppTheme.errorColor,
            title: 'Drop-off',
            address: _booking!.dropAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String title,
    required String address,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow('Distance', '${_booking!.distanceInKm.toStringAsFixed(1)} km'),
          const Divider(),
          _buildInfoRow('Duration', '${_booking!.hours} hour(s)'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProximityIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isNearDropLocation
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isNearDropLocation
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.warningColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isNearDropLocation ? Icons.check_circle : Icons.near_me,
            color: _isNearDropLocation ? AppTheme.successColor : AppTheme.warningColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isNearDropLocation
                  ? 'You are at the drop-off location!'
                  : 'Navigate to the drop-off location',
              style: TextStyle(
                color: _isNearDropLocation ? AppTheme.successColor : AppTheme.warningColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'accepted':
      case 'provider_arriving':
      case 'provider_arrived':
        return AppTheme.primaryColor;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'provider_arriving':
        return 'On the way';
      case 'provider_arrived':
        return 'Arrived at Pickup';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
        return Icons.thumb_up;
      case 'provider_arriving':
        return Icons.directions_car;
      case 'provider_arrived':
        return Icons.pin_drop;
      case 'in_progress':
        return Icons.local_shipping;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
}
