import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/location_tracking_service.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/services/api_service.dart';
import 'location_tracking_event.dart';
import 'location_tracking_state.dart';

/// BLoC for managing real-time location tracking during bookings
class LocationTrackingBloc extends Bloc<LocationTrackingEvent, LocationTrackingState> {
  final LocationTrackingService _locationService;
  final WebSocketService _wsService;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<WSMessage>? _wsLocationSubscription;
  StreamSubscription<String>? _errorSubscription;

  LocationTrackingBloc({
    LocationTrackingService? locationService,
    WebSocketService? wsService,
  })  : _locationService = locationService ?? LocationTrackingService.instance,
        _wsService = wsService ?? WebSocketService.instance,
        super(const LocationTrackingInitial()) {
    on<StartLocationTracking>(_onStartTracking);
    on<StopLocationTracking>(_onStopTracking);
    on<LocationUpdateReceived>(_onLocationUpdate);
    on<RequestOtherUserLocation>(_onRequestOtherUserLocation);
    on<LocationTrackingError>(_onError);
    on<JoinBookingRoom>(_onJoinBookingRoom);
    on<LeaveBookingRoom>(_onLeaveBookingRoom);
  }

  /// Start location tracking for a booking
  Future<void> _onStartTracking(
    StartLocationTracking event,
    Emitter<LocationTrackingState> emit,
  ) async {
    try {
      // Initialize user locations map
      final userLocations = <String, LocationData>{};

      // Start location tracking service
      final success = await _locationService.startTracking(
        userId: event.userId,
        bookingId: event.bookingId,
      );

      if (!success) {
        emit(const LocationPermissionDenied());
        return;
      }

      // Listen to position updates from device
      _positionSubscription = _locationService.positionStream.listen((position) {
        add(LocationUpdateReceived(
          userId: event.userId,
          latitude: position.latitude,
          longitude: position.longitude,
          heading: position.heading,
          speed: position.speed * 3.6, // Convert m/s to km/h
          accuracy: position.accuracy,
          timestamp: DateTime.now(),
        ));
      });

      // Listen to location updates from WebSocket (other users)
      _wsLocationSubscription = _wsService.locationStream.listen((message) {
        final data = message.data;
        if (data['userId'] != event.userId) {
          // Only process location updates from other users
          add(LocationUpdateReceived(
            userId: data['userId'] as String,
            latitude: (data['latitude'] as num).toDouble(),
            longitude: (data['longitude'] as num).toDouble(),
            heading: data['heading'] != null ? (data['heading'] as num).toDouble() : null,
            speed: data['speed'] != null ? (data['speed'] as num).toDouble() : null,
            accuracy: data['accuracy'] != null ? (data['accuracy'] as num).toDouble() : null,
            timestamp: DateTime.now(),
          ));
        }
      });

      // Listen to errors
      _errorSubscription = _locationService.errorStream.listen((error) {
        add(LocationTrackingError(message: error));
      });

      // Get initial position if available
      final lastPosition = _locationService.lastPosition;
      if (lastPosition != null) {
        userLocations[event.userId] = LocationData(
          userId: event.userId,
          latitude: lastPosition.latitude,
          longitude: lastPosition.longitude,
          heading: lastPosition.heading,
          speed: lastPosition.speed * 3.6,
          accuracy: lastPosition.accuracy,
          timestamp: DateTime.now(),
        );
      }

      emit(LocationTrackingActive(
        bookingId: event.bookingId,
        userId: event.userId,
        userLocations: userLocations,
        startedAt: DateTime.now(),
      ));

      // Request other user's location
      add(RequestOtherUserLocation(
        userId: event.userId,
        bookingId: event.bookingId,
      ));
    } catch (e) {
      emit(LocationTrackingErrorState(message: 'Failed to start tracking: $e'));
    }
  }

  /// Stop location tracking
  Future<void> _onStopTracking(
    StopLocationTracking event,
    Emitter<LocationTrackingState> emit,
  ) async {
    await _locationService.stopTracking();
    await _positionSubscription?.cancel();
    await _wsLocationSubscription?.cancel();
    await _errorSubscription?.cancel();

    _positionSubscription = null;
    _wsLocationSubscription = null;
    _errorSubscription = null;

    emit(const LocationTrackingStopped());
  }

  /// Handle location update (from own device or other user)
  void _onLocationUpdate(
    LocationUpdateReceived event,
    Emitter<LocationTrackingState> emit,
  ) {
    if (state is! LocationTrackingActive) return;

    final currentState = state as LocationTrackingActive;
    final updatedLocations = Map<String, LocationData>.from(currentState.userLocations);

    // Update or add location for user
    updatedLocations[event.userId] = LocationData(
      userId: event.userId,
      latitude: event.latitude,
      longitude: event.longitude,
      heading: event.heading,
      speed: event.speed,
      accuracy: event.accuracy,
      timestamp: event.timestamp,
    );

    emit(currentState.copyWith(userLocations: updatedLocations));
  }

  /// Request other user's location from backend
  Future<void> _onRequestOtherUserLocation(
    RequestOtherUserLocation event,
    Emitter<LocationTrackingState> emit,
  ) async {
    try {
      final response = await ApiService.instance.getBookingLocations(event.bookingId);

      if (response['success'] == true) {
        final seekerData = response['seeker'] as Map<String, dynamic>?;
        final providerData = response['provider'] as Map<String, dynamic>?;

        // Determine which is the other user
        String? otherUserId;
        Map<String, dynamic>? otherUserLocation;

        if (seekerData != null && seekerData['userId'] != event.userId) {
          otherUserId = seekerData['userId'] as String;
          otherUserLocation = seekerData['location'] as Map<String, dynamic>?;
        } else if (providerData != null && providerData['userId'] != event.userId) {
          otherUserId = providerData['userId'] as String;
          otherUserLocation = providerData['location'] as Map<String, dynamic>?;
        }

        if (otherUserId != null && otherUserLocation != null) {
          add(LocationUpdateReceived(
            userId: otherUserId,
            latitude: (otherUserLocation['latitude'] as num).toDouble(),
            longitude: (otherUserLocation['longitude'] as num).toDouble(),
            heading: otherUserLocation['heading'] != null
                ? (otherUserLocation['heading'] as num).toDouble()
                : null,
            speed: otherUserLocation['speed'] != null
                ? (otherUserLocation['speed'] as num).toDouble()
                : null,
            accuracy: otherUserLocation['accuracy'] != null
                ? (otherUserLocation['accuracy'] as num).toDouble()
                : null,
            timestamp: DateTime.now(),
          ));
        }
      }
    } catch (e) {
    }
  }

  /// Handle tracking errors
  void _onError(
    LocationTrackingError event,
    Emitter<LocationTrackingState> emit,
  ) {
    emit(LocationTrackingErrorState(message: event.message));
  }

  /// Join booking room for real-time WebSocket updates
  Future<void> _onJoinBookingRoom(
    JoinBookingRoom event,
    Emitter<LocationTrackingState> emit,
  ) async {
    // Send join room message via WebSocket
    _wsService.send({
      'type': 'join_booking_room',
      'data': {'bookingId': event.bookingId},
      'bookingId': event.bookingId,
    });
  }

  /// Leave booking room
  Future<void> _onLeaveBookingRoom(
    LeaveBookingRoom event,
    Emitter<LocationTrackingState> emit,
  ) async {
    // Send leave room message via WebSocket
    _wsService.send({
      'type': 'leave_booking_room',
      'data': {'bookingId': event.bookingId},
      'bookingId': event.bookingId,
    });
  }

  @override
  Future<void> close() async {
    await _positionSubscription?.cancel();
    await _wsLocationSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _locationService.stopTracking();
    return super.close();
  }
}
