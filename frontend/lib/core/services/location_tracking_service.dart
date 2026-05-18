import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'api_service.dart';

/// Real-time Location Tracking Service
/// Continuously tracks user location and sends updates to backend
class LocationTrackingService {
  static LocationTrackingService? _instance;
  
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<DatabaseEvent>? _firebaseLocationSubscription;
  Timer? _updateTimer;
  DatabaseReference? _bookingLocationRef;
  
  String? _currentBookingId;
  String? _userId;
  Position? _lastPosition;
  Position? _lastSentPosition;
  bool _isTracking = false;
  
  // Location update settings
  static const int updateIntervalSeconds = 3; // Send update every 3 seconds
  static const double minDistanceMeters = 10; // Only update if moved 10+ meters
  
  // Stream controllers
  final _positionController = StreamController<Position>.broadcast();
  final _otherUserLocationController = StreamController<Map<String, dynamic>>.broadcast();
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

  /// Stream of other user's location updates from Firebase Realtime DB
  Stream<Map<String, dynamic>> get otherUserLocationStream =>
      _otherUserLocationController.stream;
  
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
    _bookingLocationRef = FirebaseDatabase.instance
      .ref('booking_locations')
      .child(bookingId);
    
    // Check and request location permissions
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      _errorController.add('Location permission denied');
      return false;
    }
    
    try {
      // Get initial position
      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      // Send initial location
      await _sendLocationUpdate(_lastPosition!);
      _lastSentPosition = _lastPosition;
      
      // Start listening to location stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        _onLocationUpdate,
        onError: (error) {
          _errorController.add(error.toString());
        },
      );
      
      // Periodic timer: sends location to Firebase/API AND re-emits to the
      // position stream so the map marker always stays current even when the
      // device hasn't moved the distanceFilter threshold.
      _updateTimer = Timer.periodic(
        const Duration(seconds: updateIntervalSeconds),
        (_) async {
          if (_lastPosition != null) {
            // Re-emit the latest position so BLoC/UI refresh even without movement.
            _positionController.add(_lastPosition!);
            await _sendLocationUpdate(_lastPosition!);
            _lastSentPosition = _lastPosition;
          }
        },
      );

      // Listen for other user's live updates
      _firebaseLocationSubscription = _bookingLocationRef!.onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is! Map) return;

        data.forEach((key, value) {
          final userKey = key.toString();
          if (userKey == _userId || value is! Map) return;

          final lat = double.tryParse(value['latitude']?.toString() ?? '');
          final lng = double.tryParse(value['longitude']?.toString() ?? '');
          if (lat == null || lng == null) return;

          _otherUserLocationController.add({
            'userId': userKey,
            'latitude': lat,
            'longitude': lng,
            'heading': double.tryParse(value['heading']?.toString() ?? ''),
            'speed': double.tryParse(value['speed']?.toString() ?? ''),
            'accuracy': double.tryParse(value['accuracy']?.toString() ?? ''),
            'timestamp': value['timestamp']?.toString(),
          });
        });
      }, onError: (error) {
        _errorController.add('Failed to listen live locations: $error');
      });
      
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

    await _firebaseLocationSubscription?.cancel();
    _firebaseLocationSubscription = null;
    
    _updateTimer?.cancel();
    _updateTimer = null;
    
    _isTracking = false;

    // Remove own ephemeral live node
    if (_bookingLocationRef != null && _userId != null) {
      await _bookingLocationRef!.child(_userId!).remove();
    }

    _currentBookingId = null;
    _userId = null;
    _lastSentPosition = null;
    _bookingLocationRef = null;
    
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
    if (_lastSentPosition == null) return true;
    
    final distance = Geolocator.distanceBetween(
      _lastSentPosition!.latitude,
      _lastSentPosition!.longitude,
      position.latitude,
      position.longitude,
    );
    
    return distance >= minDistanceMeters;
  }
  
  /// Send location update to backend
  Future<void> _sendLocationUpdate(Position position) async {
    if (_userId == null || _currentBookingId == null) return;
    
    try {
      // Publish live location to Firebase Realtime Database
      if (_bookingLocationRef != null) {
        await _bookingLocationRef!.child(_userId!).set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'speed': position.speed * 3.6,
          'accuracy': position.accuracy,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Keep backend tracking endpoint in sync for existing features
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
    _otherUserLocationController.close();
    _errorController.close();
  }
}
