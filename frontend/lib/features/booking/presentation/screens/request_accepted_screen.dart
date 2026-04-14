import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';

class RequestAcceptedScreen extends StatelessWidget {
  final String bookingId;
  final String providerId;
  final String? providerName;
  final String? serviceType;
  final String? bookingStatus;
  final String? pickupAddress;
  final String? dropAddress;
  final double? estimatedPrice;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;

  const RequestAcceptedScreen({
    super.key,
    required this.bookingId,
    required this.providerId,
    this.providerName,
    this.serviceType,
    this.bookingStatus,
    this.pickupAddress,
    this.dropAddress,
    this.estimatedPrice,
    this.pickupLocation,
    this.dropoffLocation,
  });

  String _formatStatus(String? status) {
    if (status == null || status.isEmpty) return 'Accepted';
    return status
        .split('_')
        .map((part) => part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Request Accepted'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
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
                      color: AppTheme.primaryColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 30),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your request has been accepted by the provider.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                  _infoRow('Status', _formatStatus(bookingStatus)),
                  const Divider(height: 22),
                  _infoRow('Service', serviceType ?? 'Service'),
                  const Divider(height: 22),
                  _infoRow('Provider', providerName ?? 'Provider'),
                  const Divider(height: 22),
                  _infoRow('Estimated Fare', 'Rs ${estimatedPrice?.toStringAsFixed(0) ?? '0'}'),
                  if (pickupAddress != null) ...[
                    const Divider(height: 22),
                    _infoRow('Pickup', pickupAddress!),
                  ],
                  if (dropAddress != null) ...[
                    const Divider(height: 22),
                    _infoRow('Destination', dropAddress!),
                  ],
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go('/booking/$bookingId/tracking', extra: {
                    'providerId': providerId,
                    'providerName': providerName,
                    'pickupLocation': pickupLocation,
                    'dropoffLocation': dropoffLocation,
                    'pickupAddress': pickupAddress,
                    'dropAddress': dropAddress,
                    'estimatedPrice': estimatedPrice,
                    'serviceType': serviceType,
                    'bookingStatus': bookingStatus,
                  });
                },
                icon: const Icon(Icons.map_rounded),
                label: const Text(
                  'Track on Map',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
