import 'package:latlong2/latlong.dart';
import 'dart:math' show cos, sqrt, asin, sin;
import '../../../../core/constants/app_constants.dart';

class BookingService {
  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  Future<double> calculateDistance(LatLng start, LatLng end) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    const double earthRadius = 6371; // Radius of Earth in kilometers

    double lat1Rad = start.latitude * (3.141592653589793 / 180);
    double lat2Rad = end.latitude * (3.141592653589793 / 180);
    double deltaLat = (end.latitude - start.latitude) * (3.141592653589793 / 180);
    double deltaLon = (end.longitude - start.longitude) * (3.141592653589793 / 180);

    double a = (sin(deltaLat / 2) * sin(deltaLat / 2)) +
        (cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2));

    double c = 2 * asin(sqrt(a));
    double distance = earthRadius * c;

    return double.parse(distance.toStringAsFixed(2));
  }

  /// Calculate booking price based on service type and distance
  double calculatePrice({
    required String serviceType,
    required double distance,
  }) {
    final baseRate = AppConstants.baseRates[serviceType] ?? 100.0;
    final distanceCost = distance * AppConstants.pricePerKm;
    final totalPrice = baseRate + distanceCost;

    // Apply minimum charge
    if (totalPrice < AppConstants.minimumCharge) {
      return AppConstants.minimumCharge;
    }

    return double.parse(totalPrice.toStringAsFixed(2));
  }

  /// Get price breakdown for display
  Map<String, double> getPriceBreakdown({
    required String serviceType,
    required double distance,
    required double totalPrice,
  }) {
    final baseRate = AppConstants.baseRates[serviceType] ?? 100.0;
    final distanceCost = distance * AppConstants.pricePerKm;

    return {
      'baseRate': baseRate,
      'distanceCost': distanceCost,
      'total': totalPrice,
    };
  }

  /// Estimate travel time based on distance (assuming average speed of 40 km/h)
  int estimateTravelTime(double distance) {
    const double averageSpeed = 40.0; // km/h
    final hours = distance / averageSpeed;
    final minutes = (hours * 60).round();
    return minutes;
  }

  // Helper functions for Haversine formula
  double sin(double radians) {
    return radians - (radians * radians * radians) / 6 +
        (radians * radians * radians * radians * radians) / 120;
  }

  double cos(double radians) {
    return 1 - (radians * radians) / 2 +
        (radians * radians * radians * radians) / 24;
  }
}
