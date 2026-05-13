import '../../../../core/domain/entities/vehicle_entity.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/domain/entities/service_entity.dart';

abstract class ProviderRepository {
  Future<List<VehicleEntity>> getProviderVehicles(String providerId);
  Future<VehicleEntity> createVehicle({
    required String providerId,
    required String vehicleType,
    required String vehicleModel,
    required String vehicleYear,
    required String licensePlate,
    required double capacity,
    required double pricePerHour,
    required double pricePerKm,
    List<String>? imageUrls,
    String? vehicleImageBase64,
    String? vehicleLicenseImageBase64,
  });
  Future<VehicleEntity> updateVehicle(String vehicleId, Map<String, dynamic> updates);
  Future<void> deleteVehicle(String vehicleId);
  Future<List<BookingEntity>> getProviderBookings(String providerId);
  Future<BookingEntity> acceptBooking(String bookingId, String providerId);
  Future<BookingEntity> rejectBooking(String bookingId, String providerId, {String? reason});
  Future<BookingEntity> completeBooking(String bookingId, {double? finalPrice});
  
  // Service management
  Future<List<ServiceEntity>> getProviderServices(String providerId);
  Future<List<ServiceEntity>> getVehicleServices(String vehicleId);
  Future<ServiceEntity> createService({
    required String providerId,
    required String vehicleId,
    required String name,
    required String description,
    String? imageUrl,
    required double basePrice,
    required double pricePerKm,
    required double pricePerHour,
    required String category,
    String? extraFields,
    double? serviceBaseLatitude,
    double? serviceBaseLongitude,
    String? serviceBaseAddress,
  });
  Future<ServiceEntity> updateService(String serviceId, Map<String, dynamic> updates);
  Future<void> deleteService(String serviceId);
}
