import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/domain/entities/location_entity.dart';
import '../../../services/domain/entities/service_entity.dart';

abstract class BookingState extends Equatable {
  const BookingState();

  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {
  const BookingInitial();
}

class BookingInProgress extends BookingState {
  final String? serviceType;
  final ServiceEntity? service;
  final LatLng? pickupLocation;
  final String? pickupAddress;
  final LatLng? dropLocation;
  final String? dropAddress;
  final DateTime? scheduledDateTime;
  final double? distance;
  final double? estimatedPrice;
  final String? notes;

  const BookingInProgress({
    this.serviceType,
    this.service,
    this.pickupLocation,
    this.pickupAddress,
    this.dropLocation,
    this.dropAddress,
    this.scheduledDateTime,
    this.distance,
    this.estimatedPrice,
    this.notes,
  });

  bool get isReadyForPriceCalculation =>
      serviceType != null &&
      pickupLocation != null &&
      dropLocation != null;

  bool get isReadyForSubmission =>
      isReadyForPriceCalculation &&
      scheduledDateTime != null &&
      estimatedPrice != null;

  BookingInProgress copyWith({
    String? serviceType,
    ServiceEntity? service,
    LatLng? pickupLocation,
    String? pickupAddress,
    LatLng? dropLocation,
    String? dropAddress,
    DateTime? scheduledDateTime,
    double? distance,
    double? estimatedPrice,
    String? notes,
  }) {
    return BookingInProgress(
      serviceType: serviceType ?? this.serviceType,
      service: service ?? this.service,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropLocation: dropLocation ?? this.dropLocation,
      dropAddress: dropAddress ?? this.dropAddress,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      distance: distance ?? this.distance,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        serviceType,
        service,
        pickupLocation,
        pickupAddress,
        dropLocation,
        dropAddress,
        scheduledDateTime,
        distance,
        estimatedPrice,
        notes,
      ];
}

class BookingCalculating extends BookingState {
  final BookingInProgress currentState;

  const BookingCalculating({required this.currentState});

  @override
  List<Object?> get props => [currentState];
}

class BookingSubmitting extends BookingState {
  final BookingInProgress bookingData;

  const BookingSubmitting({required this.bookingData});

  @override
  List<Object?> get props => [bookingData];
}

class BookingSuccess extends BookingState {
  final String bookingId;
  final String message;
  final BookingInProgress? bookingData;

  const BookingSuccess({
    required this.bookingId,
    required this.message,
    this.bookingData,
  });

  @override
  List<Object?> get props => [bookingId, message, bookingData];
}

class BookingError extends BookingState {
  final String message;
  final BookingInProgress? currentState;

  const BookingError({
    required this.message,
    this.currentState,
  });

  @override
  List<Object?> get props => [message, currentState];
}

// ===== Booking List States =====

/// State when loading bookings list
class BookingsLoading extends BookingState {
  const BookingsLoading();
}

/// State with loaded bookings list
class BookingsLoaded extends BookingState {
  final List<BookingEntity> bookings;
  final bool isProvider;

  const BookingsLoaded({
    required this.bookings,
    this.isProvider = false,
  });

  @override
  List<Object?> get props => [bookings, isProvider];
}

/// State with available bookings for providers
class AvailableBookingsLoaded extends BookingState {
  final List<BookingEntity> bookings;

  const AvailableBookingsLoaded({required this.bookings});

  @override
  List<Object?> get props => [bookings];
}

// ===== Active Booking Tracking States =====

/// State when actively tracking a booking
class BookingTracking extends BookingState {
  final BookingEntity booking;
  final LocationEntity? providerLocation;
  final int? estimatedArrivalMinutes;
  final double? distanceToDestination;

  const BookingTracking({
    required this.booking,
    this.providerLocation,
    this.estimatedArrivalMinutes,
    this.distanceToDestination,
  });

  BookingTracking copyWith({
    BookingEntity? booking,
    LocationEntity? providerLocation,
    int? estimatedArrivalMinutes,
    double? distanceToDestination,
  }) {
    return BookingTracking(
      booking: booking ?? this.booking,
      providerLocation: providerLocation ?? this.providerLocation,
      estimatedArrivalMinutes: estimatedArrivalMinutes ?? this.estimatedArrivalMinutes,
      distanceToDestination: distanceToDestination ?? this.distanceToDestination,
    );
  }

  @override
  List<Object?> get props => [
        booking,
        providerLocation,
        estimatedArrivalMinutes,
        distanceToDestination,
      ];
}

/// Provider is on the way
class ProviderArrivingState extends BookingState {
  final BookingEntity booking;
  final LocationEntity? providerLocation;
  final int? estimatedMinutes;

  const ProviderArrivingState({
    required this.booking,
    this.providerLocation,
    this.estimatedMinutes,
  });

  @override
  List<Object?> get props => [booking, providerLocation, estimatedMinutes];
}

/// Provider has arrived
class ProviderArrivedState extends BookingState {
  final BookingEntity booking;

  const ProviderArrivedState({required this.booking});

  @override
  List<Object?> get props => [booking];
}

/// Booking is in progress (service being delivered)
class BookingInProgressState extends BookingState {
  final BookingEntity booking;
  final LocationEntity? currentLocation;
  final DateTime startedAt;

  const BookingInProgressState({
    required this.booking,
    this.currentLocation,
    required this.startedAt,
  });

  @override
  List<Object?> get props => [booking, currentLocation, startedAt];
}

/// Booking completed successfully
class BookingCompletedState extends BookingState {
  final BookingEntity booking;
  final double finalPrice;
  final bool hasRated;

  const BookingCompletedState({
    required this.booking,
    required this.finalPrice,
    this.hasRated = false,
  });

  @override
  List<Object?> get props => [booking, finalPrice, hasRated];
}

/// Booking was cancelled
class BookingCancelledState extends BookingState {
  final BookingEntity booking;
  final String reason;
  final String cancelledBy;

  const BookingCancelledState({
    required this.booking,
    required this.reason,
    required this.cancelledBy,
  });

  @override
  List<Object?> get props => [booking, reason, cancelledBy];
}

/// Processing a booking action (status update, cancel, etc.)
class BookingActionProcessing extends BookingState {
  final String bookingId;
  final String action;

  const BookingActionProcessing({
    required this.bookingId,
    required this.action,
  });

  @override
  List<Object?> get props => [bookingId, action];
}
