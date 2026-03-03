import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/domain/entities/location_entity.dart';
import '../../../services/domain/entities/service_entity.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

// ===== Booking Creation Events =====

class BookingServiceSelected extends BookingEvent {
  final String serviceType;
  final ServiceEntity? service;

  const BookingServiceSelected({
    required this.serviceType,
    this.service,
  });

  @override
  List<Object?> get props => [serviceType, service];
}

class BookingPickupLocationSelected extends BookingEvent {
  final LatLng location;
  final String address;

  const BookingPickupLocationSelected({
    required this.location,
    required this.address,
  });

  @override
  List<Object?> get props => [location, address];
}

class BookingDropLocationSelected extends BookingEvent {
  final LatLng location;
  final String address;

  const BookingDropLocationSelected({
    required this.location,
    required this.address,
  });

  @override
  List<Object?> get props => [location, address];
}

class BookingDateTimeSelected extends BookingEvent {
  final DateTime dateTime;

  const BookingDateTimeSelected({required this.dateTime});

  @override
  List<Object?> get props => [dateTime];
}

class BookingCalculatePriceRequested extends BookingEvent {
  const BookingCalculatePriceRequested();
}

class BookingNotesUpdated extends BookingEvent {
  final String notes;

  const BookingNotesUpdated({required this.notes});

  @override
  List<Object?> get props => [notes];
}

class BookingSubmitRequested extends BookingEvent {
  const BookingSubmitRequested();
}

class BookingReset extends BookingEvent {
  const BookingReset();
}

// ===== Booking Lifecycle Events =====

/// Load a specific booking by ID
class LoadBookingRequested extends BookingEvent {
  final String bookingId;

  const LoadBookingRequested({required this.bookingId});

  @override
  List<Object?> get props => [bookingId];
}

/// Load user's bookings (for seeker or provider)
class LoadUserBookingsRequested extends BookingEvent {
  final String userId;
  final bool isProvider;
  final String? status;

  const LoadUserBookingsRequested({
    required this.userId,
    this.isProvider = false,
    this.status,
  });

  @override
  List<Object?> get props => [userId, isProvider, status];
}

/// Load available bookings for providers
class LoadAvailableBookingsRequested extends BookingEvent {
  final String? serviceType;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;

  const LoadAvailableBookingsRequested({
    this.serviceType,
    this.latitude,
    this.longitude,
    this.radiusKm,
  });

  @override
  List<Object?> get props => [serviceType, latitude, longitude, radiusKm];
}

// ===== Status Update Events =====

/// Provider marks as arriving
class ProviderArrivingRequested extends BookingEvent {
  final String bookingId;
  final int? estimatedMinutes;

  const ProviderArrivingRequested({
    required this.bookingId,
    this.estimatedMinutes,
  });

  @override
  List<Object?> get props => [bookingId, estimatedMinutes];
}

/// Provider marks as arrived
class ProviderArrivedRequested extends BookingEvent {
  final String bookingId;

  const ProviderArrivedRequested({required this.bookingId});

  @override
  List<Object?> get props => [bookingId];
}

/// Provider starts the booking
class StartBookingRequested extends BookingEvent {
  final String bookingId;

  const StartBookingRequested({required this.bookingId});

  @override
  List<Object?> get props => [bookingId];
}

/// Provider completes the booking
class CompleteBookingRequested extends BookingEvent {
  final String bookingId;
  final double? finalPrice;

  const CompleteBookingRequested({
    required this.bookingId,
    this.finalPrice,
  });

  @override
  List<Object?> get props => [bookingId, finalPrice];
}

/// Cancel a booking (seeker or provider)
class CancelBookingRequested extends BookingEvent {
  final String bookingId;
  final String reason;

  const CancelBookingRequested({
    required this.bookingId,
    required this.reason,
  });

  @override
  List<Object?> get props => [bookingId, reason];
}

/// Rate a completed booking
class RateBookingRequested extends BookingEvent {
  final String bookingId;
  final double rating;
  final String? review;

  const RateBookingRequested({
    required this.bookingId,
    required this.rating,
    this.review,
  });

  @override
  List<Object?> get props => [bookingId, rating, review];
}

// ===== Real-time Events (from WebSocket) =====

/// Booking status updated via WebSocket
class BookingStatusReceived extends BookingEvent {
  final String bookingId;
  final String status;
  final Map<String, dynamic>? data;

  const BookingStatusReceived({
    required this.bookingId,
    required this.status,
    this.data,
  });

  @override
  List<Object?> get props => [bookingId, status, data];
}

/// Provider location update received
class ProviderLocationReceived extends BookingEvent {
  final String bookingId;
  final LocationEntity location;

  const ProviderLocationReceived({
    required this.bookingId,
    required this.location,
  });

  @override
  List<Object?> get props => [bookingId, location];
}

/// New booking request received (for providers)
class NewBookingRequestReceived extends BookingEvent {
  final BookingEntity booking;

  const NewBookingRequestReceived({required this.booking});

  @override
  List<Object?> get props => [booking];
}

/// Start tracking a booking
class StartTrackingBooking extends BookingEvent {
  final String bookingId;

  const StartTrackingBooking({required this.bookingId});

  @override
  List<Object?> get props => [bookingId];
}

/// Stop tracking a booking
class StopTrackingBooking extends BookingEvent {
  final String bookingId;

  const StopTrackingBooking({required this.bookingId});

  @override
  List<Object?> get props => [bookingId];
}
