import 'package:equatable/equatable.dart';

/// Events for Location Tracking BLoC
abstract class LocationTrackingEvent extends Equatable {
  const LocationTrackingEvent();

  @override
  List<Object?> get props => [];
}

/// Start tracking location for a booking
class StartLocationTracking extends LocationTrackingEvent {
  final String userId;
  final String bookingId;

  const StartLocationTracking({
    required this.userId,
    required this.bookingId,
  });

  @override
  List<Object?> get props => [userId, bookingId];
}

/// Stop tracking location
class StopLocationTracking extends LocationTrackingEvent {
  const StopLocationTracking();
}

/// Location update received (from own device or other user via FCM)
class LocationUpdateReceived extends LocationTrackingEvent {
  final String userId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final DateTime timestamp;

  LocationUpdateReceived({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [
        userId,
        latitude,
        longitude,
        heading,
        speed,
        accuracy,
        timestamp,
      ];
}

/// Request other user's location
class RequestOtherUserLocation extends LocationTrackingEvent {
  final String userId;
  final String bookingId;

  const RequestOtherUserLocation({
    required this.userId,
    required this.bookingId,
  });

  @override
  List<Object?> get props => [userId, bookingId];
}

/// Error occurred during tracking
class LocationTrackingError extends LocationTrackingEvent {
  final String message;

  const LocationTrackingError({required this.message});

  @override
  List<Object?> get props => [message];
}
