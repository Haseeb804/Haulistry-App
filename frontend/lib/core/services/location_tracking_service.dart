import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'api_service.dart';

/// Real-time Location Tracking Service
/// Continuously tracks user location and sends updates to backend
class LocationTrackingService {
  static LocationTrackingService? _instance;
  
  StreamSubscription<Position>? _positionSubscription;
  Timer? _updateTimer;
  
  String? _currentBookingId;
  String? _userId;
  Position? _lastPosition;
  bool _isTracking = false;
  
  // Location update settings
  static const int updateIntervalSeconds = 5; // Send update every 5 seconds
  static const double minDistanceMeters = 10; // Only update if moved 10+ meters
  
  // Stream controllers
  final _positionController = StreamController<Position>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  LocationTrackingService._();
  
  static LocationTrackingService get instance {
    _instance ??= LocationTrackingService._();
    return _instance!;
  }
  
  /// Stream of position updates
  Stream<Position> get positionStream => _positionController.stream;
  
  /// Stream of errors
  Stream<String> get errorStream => _errorController.stream;
  
  /// Check if currently tracking
  bool get isTracking => _isTracking;
  
  /// Get last known position
  Position? get lastPosition => _lastPosition;
  
  /// Start real-time location tracking for a booking
  Future<bool> startTracking({
    required String userId,
    required String bookingId,
  }) async {
    if (_isTracking) {
      return true;
    }
    
    _userId = userId;
    _currentBookingId = bookingId;
    
    // Check and request location permissions
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      _errorController.add('Location permission denied');
      return false;
    }
    
    try {
      // Get initial position
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Send initial location
      await _sendLocationUpdate(_lastPosition!);
      
      // Start listening to location stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        _onLocationUpdate,
        onError: (error) {
          _errorController.add(error.toString());
        },
      );
      
      // Start periodic update timer (backup if distance filter doesn't trigger)
      _updateTimer = Timer.periodic(
        const Duration(seconds: updateIntervalSeconds),
        (_) async {
          if (_lastPosition != null) {
            await _sendLocationUpdate(_lastPosition!);
          }
        },
      );
      
      _isTracking = true;
      return true;
      
    } catch (e) {
      _errorController.add('Failed to start tracking: $e');
      return false;
    }
  }
  
  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;
    
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    
    _updateTimer?.cancel();
    _updateTimer = null;
    
    _isTracking = false;
    _currentBookingId = null;
    _userId = null;
    
  }
  
  /// Handle location updates from stream
  void _onLocationUpdate(Position position) {
    _lastPosition = position;
    _positionController.add(position);
    
    // Send to backend (debounced by distance filter and timer)
    if (_shouldSendUpdate(position)) {
      _sendLocationUpdate(position);
    }
  }
  
  /// Check if we should send an update based on distance moved
  bool _shouldSendUpdate(Position position) {
    if (_lastPosition == null) return true;
    
    final distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    );
    
    return distance >= minDistanceMeters;
  }
  
  /// Send location update to backend
  Future<void> _sendLocationUpdate(Position position) async {
    if (_userId == null || _currentBookingId == null) return;
    
    try {
      await ApiService.updateBookingLocation(
        bookingId: _currentBookingId!,
        userId: _userId!,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        speed: position.speed * 3.6, // Convert m/s to km/h
        accuracy: position.accuracy,
      );
      
    } catch (e) {
      _errorController.add('Failed to send location: $e');
    }
  }
  
  /// Check and request location permissions
  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _errorController.add('Location services are disabled');
      return false;
    }
    
    return true;
  }
  
  /// Convert Position to LatLng
  LatLng positionToLatLng(Position position) {
    return LatLng(position.latitude, position.longitude);
  }
  
  /// Dispose resources
  void dispose() {
    stopTracking();
    _positionController.close();
    _errorController.close();
  }
}
