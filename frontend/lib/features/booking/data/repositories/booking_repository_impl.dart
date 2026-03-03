import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';
import '../../../../core/domain/entities/booking_entity.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource remoteDataSource;

  BookingRepositoryImpl({required this.remoteDataSource});

  @override
  Future<BookingEntity> createBooking({
    required String userId,
    required String serviceType,
    required String pickupLocation,
    required String dropoffLocation,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required String scheduledDate,
    required double estimatedPrice,
    required double distance,
    String? serviceId,
    String? providerId,
    String? vehicleId,
    int hours = 1,
    bool isUrgent = false,
    String? notes,
  }) async {
    try {
      final bookingData = {
        'seekerId': userId,
        'serviceType': serviceType,
        'serviceId': serviceId,
        'providerId': providerId,
        'vehicleId': vehicleId,
        'pickupAddress': pickupLocation,
        'dropAddress': dropoffLocation,
        'pickupLatitude': pickupLat,
        'pickupLongitude': pickupLng,
        'dropLatitude': dropoffLat,
        'dropLongitude': dropoffLng,
        'scheduledDateTime': scheduledDate,
        'estimatedPrice': estimatedPrice,
        'distanceInKm': distance,
        'hours': hours,
        'isUrgent': isUrgent,
        'notes': notes,
      };

      return await remoteDataSource.createBooking(bookingData);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<BookingEntity>> getUserBookings(String userId) async {
    try {
      return await remoteDataSource.getUserBookings(userId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<BookingEntity>> getBookingHistory(String userId, {String? status}) async {
    try {
      final bookings = await remoteDataSource.getUserBookings(userId);
      if (status != null) {
        return bookings.where((b) => b.status == status).toList();
      }
      return bookings;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<BookingEntity> getBookingById(String bookingId) async {
    try {
      return await remoteDataSource.getBookingById(bookingId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<BookingEntity> updateBookingStatus(String bookingId, String status) async {
    try {
      return await remoteDataSource.updateBookingStatus(bookingId, status);
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
  Future<BookingEntity> completeBooking(String bookingId) async {
    try {
      return await remoteDataSource.completeBooking(bookingId);
    } catch (e) {
      rethrow;
    }
  }
}
