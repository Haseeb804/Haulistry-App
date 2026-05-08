import '../../domain/repositories/provider_repository.dart';
import '../datasources/provider_remote_datasource.dart';
import '../../../../core/domain/entities/vehicle_entity.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/domain/entities/service_entity.dart';

class ProviderRepositoryImpl implements ProviderRepository {
  final ProviderRemoteDataSource remoteDataSource;

  ProviderRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<VehicleEntity>> getProviderVehicles(String providerId) async {
    try {
      return await remoteDataSource.getProviderVehicles(providerId);
    } catch (e) {
      rethrow;
    }
  }

  @override
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
  }) async {
    try {
      final vehicleData = {
        'providerId': providerId,
        'vehicleType': vehicleType,
        'vehicleModel': vehicleModel,
        'vehicleYear': vehicleYear,
        'vehicleNumber': licensePlate,
        'capacity': capacity,
        'isAvailable': true,
        if (vehicleImageBase64 != null) 'vehicleImageBase64': vehicleImageBase64,
        if (vehicleLicenseImageBase64 != null) 'vehicleLicenseImageBase64': vehicleLicenseImageBase64,
      };

      return await remoteDataSource.createVehicle(vehicleData);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<VehicleEntity> updateVehicle(String vehicleId, Map<String, dynamic> updates) async {
    try {
      return await remoteDataSource.updateVehicle(vehicleId, updates);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await remoteDataSource.deleteVehicle(vehicleId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<BookingEntity>> getProviderBookings(String providerId) async {
    try {
      return await remoteDataSource.getProviderBookings(providerId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<BookingEntity> acceptBooking(String bookingId, String providerId) async {
    try {
      return await remoteDataSource.acceptBooking(bookingId, providerId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<BookingEntity> rejectBooking(String bookingId, String providerId, {String? reason}) async {
    try {
      return await remoteDataSource.rejectBooking(bookingId, providerId, reason: reason);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<BookingEntity> completeBooking(String bookingId, {double? finalPrice}) async {
    try {
      return await remoteDataSource.completeBooking(bookingId, finalPrice: finalPrice);
    } catch (e) {
      rethrow;
    }
  }

  // ===== SERVICE MANAGEMENT =====

  @override
  Future<List<ServiceEntity>> getProviderServices(String providerId) async {
    try {
      return await remoteDataSource.getProviderServices(providerId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ServiceEntity>> getVehicleServices(String vehicleId) async {
    try {
      return await remoteDataSource.getVehicleServices(vehicleId);
    } catch (e) {
      rethrow;
    }
  }

  @override
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
  }) async {
    try {
      final serviceData = {
        'providerId': providerId,
        'vehicleId': vehicleId,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'basePrice': basePrice,
        'pricePerKm': pricePerKm,
        'pricePerHour': pricePerHour,
        'category': category,
        if (extraFields != null) 'extraFields': extraFields,
      };

      return await remoteDataSource.createService(serviceData);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ServiceEntity> updateService(String serviceId, Map<String, dynamic> updates) async {
    try {
      return await remoteDataSource.updateService(serviceId, updates);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteService(String serviceId) async {
    try {
      await remoteDataSource.deleteService(serviceId);
    } catch (e) {
      rethrow;
    }
  }
}
