import '../../../../core/domain/entities/booking_entity.dart';

abstract class BookingRepository {
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
  });

  Future<List<BookingEntity>> getUserBookings(String userId);
  Future<List<BookingEntity>> getBookingHistory(String userId, {String? status});
  Future<BookingEntity> getBookingById(String bookingId);
  Future<BookingEntity> updateBookingStatus(String bookingId, String status);
  Future<BookingEntity> acceptBooking(String bookingId, String providerId);
  Future<BookingEntity> completeBooking(String bookingId);
}
