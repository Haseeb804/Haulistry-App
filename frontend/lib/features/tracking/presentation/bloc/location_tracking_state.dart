import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// States for Location Tracking BLoC
abstract class LocationTrackingState extends Equatable {
  const LocationTrackingState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no tracking
class LocationTrackingInitial extends LocationTrackingState {
  const LocationTrackingInitial();
}

/// Tracking is active
class LocationTrackingActive extends LocationTrackingState {
  final String bookingId;
  final String userId;
  final Map<String, LocationData> userLocations; // userId -> LocationData
  final DateTime startedAt;

  const LocationTrackingActive({
    required this.bookingId,
    required this.userId,
    required this.userLocations,
    required this.startedAt,
  });

  @override
  List<Object?> get props => [bookingId, userId, userLocations, startedAt];

  /// Copy with updated locations
  LocationTrackingActive copyWith({
    Map<String, LocationData>? userLocations,
  }) {
    return LocationTrackingActive(
      bookingId: bookingId,
      userId: userId,
      userLocations: userLocations ?? this.userLocations,
      startedAt: startedAt,
    );
  }

  /// Get LatLng for a user
  LatLng? getUserLatLng(String userId) {
    final location = userLocations[userId];
    if (location == null) return null;
    return LatLng(location.latitude, location.longitude);
  }

  /// Get own location
  LocationData? get myLocation => userLocations[userId];

  /// Get other user's location (assumes 2 users in booking)
  LocationData? get otherUserLocation {
    for (final loc in userLocations.values) {
      if (loc.userId != userId) {
        return loc;
      }
    }
    return null;
  }

  /// Check if we have other user's location
  bool get hasOtherUserLocation {
    return userLocations.values.any((loc) => loc.userId != userId);
  }
}

/// Location tracking stopped
class LocationTrackingStopped extends LocationTrackingState {
  const LocationTrackingStopped();
}

/// Error during tracking
class LocationTrackingErrorState extends LocationTrackingState {
  final String message;

  const LocationTrackingErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Location permission denied
class LocationPermissionDenied extends LocationTrackingState {
  const LocationPermissionDenied();
}

/// Location Data Model
class LocationData extends Equatable {
  final String userId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final DateTime timestamp;

  const LocationData({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
    required this.timestamp,
  });

  /// Convert to LatLng
  LatLng toLatLng() => LatLng(latitude, longitude);

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

  /// Copy with updated values
  LocationData copyWith({
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
    double? accuracy,
    DateTime? timestamp,
  }) {
    return LocationData(
      userId: userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Create from JSON
  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      userId: json['userId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      heading: json['heading'] != null ? (json['heading'] as num).toDouble() : null,
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
      if (accuracy != null) 'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
