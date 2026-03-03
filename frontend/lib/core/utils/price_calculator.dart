import '../constants/app_constants.dart';

/// Service for calculating dynamic pricing based on vehicle type and distance
class PriceCalculator {
  /// Calculate total price for a service
  /// 
  /// Formula: Base Rate + (Distance × Price Per KM) + Additional Charges
  /// Returns minimum charge if calculated price is lower
  static double calculatePrice({
    required String serviceType,
    required double distanceInKm,
    int hours = 1,
    bool isUrgent = false,
    bool nightTime = false,
  }) {
    // Get base rate for service type
    double baseRate = AppConstants.baseRates[serviceType] ?? 100.0;
    
    // Calculate distance charge
    double distanceCharge = distanceInKm * AppConstants.pricePerKm;
    
    // Calculate hourly rate (for services like harvesters)
    double hourlyCharge = baseRate * hours;
    
    // Calculate base price
    double basePrice = baseRate + distanceCharge + (hours > 1 ? hourlyCharge : 0);
    
    // Apply surge pricing for urgent requests (20% extra)
    if (isUrgent) {
      basePrice *= 1.2;
    }
    
    // Apply night time charges (15% extra) - 8 PM to 6 AM
    if (nightTime) {
      basePrice *= 1.15;
    }
    
    // Ensure minimum charge
    double finalPrice = basePrice < AppConstants.minimumCharge 
        ? AppConstants.minimumCharge 
        : basePrice;
    
    // Round to 2 decimal places
    return double.parse(finalPrice.toStringAsFixed(2));
  }
  
  /// Calculate estimated price range
  static Map<String, double> calculatePriceRange({
    required String serviceType,
    required double minDistance,
    required double maxDistance,
  }) {
    double minPrice = calculatePrice(
      serviceType: serviceType,
      distanceInKm: minDistance,
    );
    
    double maxPrice = calculatePrice(
      serviceType: serviceType,
      distanceInKm: maxDistance,
      isUrgent: true,
      nightTime: true,
    );
    
    return {
      'min': minPrice,
      'max': maxPrice,
    };
  }
  
  /// Get breakdown of price components
  static Map<String, dynamic> getPriceBreakdown({
    required String serviceType,
    required double distanceInKm,
    int hours = 1,
    bool isUrgent = false,
    bool nightTime = false,
  }) {
    double baseRate = AppConstants.baseRates[serviceType] ?? 100.0;
    double distanceCharge = distanceInKm * AppConstants.pricePerKm;
    double hourlyCharge = hours > 1 ? baseRate * (hours - 1) : 0;
    double subtotal = baseRate + distanceCharge + hourlyCharge;
    
    double urgentSurcharge = isUrgent ? subtotal * 0.2 : 0;
    double nightSurcharge = nightTime ? (subtotal + urgentSurcharge) * 0.15 : 0;
    
    double total = subtotal + urgentSurcharge + nightSurcharge;
    total = total < AppConstants.minimumCharge ? AppConstants.minimumCharge : total;
    
    return {
      'baseRate': baseRate,
      'distanceCharge': distanceCharge,
      'hourlyCharge': hourlyCharge,
      'subtotal': subtotal,
      'urgentSurcharge': urgentSurcharge,
      'nightSurcharge': nightSurcharge,
      'total': double.parse(total.toStringAsFixed(2)),
    };
  }
}
