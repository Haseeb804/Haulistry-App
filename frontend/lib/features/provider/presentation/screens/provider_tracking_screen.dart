import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../call/presentation/bloc/call_bloc.dart';
import '../../../call/presentation/bloc/call_event.dart';
import '../../../tracking/presentation/bloc/location_tracking_bloc.dart';
import '../../../tracking/presentation/bloc/location_tracking_event.dart';
import '../../../tracking/presentation/bloc/location_tracking_state.dart' as loc;
import '../bloc/provider_bloc.dart';
import '../bloc/provider_event.dart';
import '../bloc/provider_state.dart';

class ProviderTrackingScreen extends StatefulWidget {
  final String bookingId;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final String? pickupAddress;
  final String? dropAddress;
  final double? estimatedPrice;
  final String? serviceType;
  final String? bookingStatus;

  const ProviderTrackingScreen({
    super.key,
    required this.bookingId,
    this.pickupLocation,
    this.dropoffLocation,
    this.pickupAddress,
    this.dropAddress,
    this.estimatedPrice,
    this.serviceType,
    this.bookingStatus,
  });

  @override
  State<ProviderTrackingScreen> createState() => _ProviderTrackingScreenState();
}

class _ProviderTrackingScreenState extends State<ProviderTrackingScreen> {
  MapController? _mapController;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  List<LatLng> _routePoints = [];
  Position? _currentPosition;
  LatLng? _seekerDisplayLocation;
  BookingEntity? _booking;
  bool _isNearDropLocation = false;
  bool _autoFollowSeeker = false;
  Timer? _seekerAnimationTimer;
  static const double _completionRadiusMeters = 100;

  bool get _isActiveServiceStatus {
    final status = (widget.bookingStatus ?? '').toLowerCase();
    return status == 'accepted' ||
        status == 'provider_arriving' ||
        status == 'provider_arrived' ||
        status == 'in_progress';
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isActiveServiceStatus) return;
      _setupMap();
      _startLocationTracking();
    });
  }

  @override
  void dispose() {
    // Stop location tracking when leaving screen
    _seekerAnimationTimer?.cancel();
    context.read<LocationTrackingBloc>().add(const StopLocationTracking());
    super.dispose();
  }

  void _animateSeekerMarkerTo(LatLng target) {
    _seekerAnimationTimer?.cancel();

    final start = _seekerDisplayLocation;
    if (start == null) {
      _seekerDisplayLocation = target;
      _updateMarkers();
      return;
    }

    const steps = 14;
    var step = 0;
    _seekerAnimationTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      step++;
      final t = Curves.easeOutCubic.transform(step / steps);
      final lat = start.latitude + (target.latitude - start.latitude) * t;
      final lng = start.longitude + (target.longitude - start.longitude) * t;

      setState(() {
        _seekerDisplayLocation = LatLng(lat, lng);
      });
      _updateMarkers();

      if (step >= steps) {
        timer.cancel();
      }
    });
  }

  void _startLocationTracking() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.bookingId.isNotEmpty) {
      context.read<LocationTrackingBloc>().add(
        StartLocationTracking(
          userId: user.uid,
          bookingId: widget.bookingId,
        ),
      );
    }
  }

  void _onLocationUpdate(loc.LocationData myLocation) {
    _currentPosition = Position(
      latitude: myLocation.latitude,
      longitude: myLocation.longitude,
      timestamp: myLocation.timestamp,
      accuracy: myLocation.accuracy ?? 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: myLocation.heading ?? 0,
      headingAccuracy: 0,
      speed: (myLocation.speed ?? 0) / 3.6, // Convert km/h to m/s
      speedAccuracy: 0,
    );
    _updateMarkers();

    if (widget.dropoffLocation != null) {
      final distanceToDropM = Geolocator.distanceBetween(
        myLocation.latitude,
        myLocation.longitude,
        widget.dropoffLocation!.latitude,
        widget.dropoffLocation!.longitude,
      );

      final wasNear = _isNearDropLocation;
      _isNearDropLocation = distanceToDropM <= _completionRadiusMeters;

      if (_isNearDropLocation && !wasNear && _booking?.status == 'in_progress') {
        _showAutoCompleteDialog();
      }
    }

    if (mounted) setState(() {});
  }

  void _showAutoCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('You\'ve Arrived!'),
        content: const Text(
          'You have reached the drop-off location. Would you like to mark this booking as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _completeBooking();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
            child: const Text('Complete Booking'),
          ),
        ],
      ),
    );
  }

  void _completeBooking() {
    context.read<ProviderBloc>().add(
      ProviderCompleteBookingRequested(bookingId: widget.bookingId),
    );
  }

  void _setupMap() {
    _updateMarkers();
    _fetchRoute();
  }

  void _updateMarkers() {
    List<Marker> markers = [];

    // Provider's current location (you)
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing animation circle
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
              // Inner truck icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      );
    }

    // Pickup location
    if (widget.pickupLocation != null) {
      markers.add(
        Marker(
          point: widget.pickupLocation!,
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.secondaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.trip_origin, color: Colors.white, size: 24),
          ),
        ),
      );
    }

    // Drop-off location
    if (widget.dropoffLocation != null) {
      markers.add(
        Marker(
          point: widget.dropoffLocation!,
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
          ),
        ),
      );
    }
    
    // Seeker's real-time location
    if (_seekerDisplayLocation != null) {
      markers.add(
        Marker(
          point: _seekerDisplayLocation!,
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _fetchRoute() async {
    if (widget.pickupLocation == null || widget.dropoffLocation == null) return;

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${widget.pickupLocation!.longitude},${widget.pickupLocation!.latitude};'
          '${widget.dropoffLocation!.longitude},${widget.dropoffLocation!.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;

          setState(() {
            _routePoints = coordinates.map((coord) {
              return LatLng(coord[1].toDouble(), coord[0].toDouble());
            }).toList();

            _polylines = [
              Polyline(
                points: _routePoints,
                color: AppTheme.accentColor,
                strokeWidth: 5.0,
              ),
            ];
          });

          _fitMapToRoute();
        }
      }
    } catch (e) {
      debugPrint('Route fetch failed: $e');
    }
  }

  void _fitMapToRoute() {
    if (_mapController == null) return;

    List<LatLng> allPoints = [..._routePoints];
    if (_currentPosition != null) {
      allPoints.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
    }
    if (widget.pickupLocation != null) allPoints.add(widget.pickupLocation!);
    if (widget.dropoffLocation != null) allPoints.add(widget.dropoffLocation!);

    if (allPoints.isEmpty) return;

    double minLat = allPoints.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    double maxLat = allPoints.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    double minLng = allPoints.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    double maxLng = allPoints.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    final bounds = LatLngBounds(
      LatLng(minLat - 0.01, minLng - 0.01),
      LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    _mapController!.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  void _centerOnCurrentLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        15,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isActiveServiceStatus) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          title: const Text('Tracking Unavailable'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: AppTheme.errorColor, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Live tracking is only available during an active service.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This booking is ${widget.bookingStatus ?? 'unavailable'}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/provider/history'),
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Back to History'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MultiBlocListener(
      listeners: [
        // Listen to location tracking updates
        BlocListener<LocationTrackingBloc, loc.LocationTrackingState>(
          listener: (context, state) {
            if (state is loc.LocationTrackingActive) {
              // Update my own location
              final myLoc = state.myLocation;
              if (myLoc != null) {
                _onLocationUpdate(myLoc);
              }
              
              // Update seeker location
              final seekerLoc = state.otherUserLocation;
              if (seekerLoc != null) {
                final target = LatLng(seekerLoc.latitude, seekerLoc.longitude);
                _animateSeekerMarkerTo(target);

                if (_autoFollowSeeker && _seekerDisplayLocation != null) {
                  _mapController?.move(_seekerDisplayLocation!, _mapController?.camera.zoom ?? 15);
                }
              }
            } else if (state is loc.LocationTrackingErrorState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Location tracking error: ${state.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
        // Listen to provider booking actions
        BlocListener<ProviderBloc, ProviderState>(
          listener: (context, state) {
            if (state is ProviderBookingActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(state.message),
                    ],
                  ),
                  backgroundColor: AppTheme.successColor,
                ),
              );
              
              // Navigate to feedback screen after completing booking
              if (_booking != null) {
                context.go('/feedback/provider', extra: {
                  'bookingId': widget.bookingId,
                  'seekerId': _booking!.seekerId,
                  'seekerName': _booking!.seekerName ?? 'Customer',
                });
              } else {
                context.go('/provider/home');
              }
            } else if (state is ProviderError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
        ), // End of second BlocListener
      ], // End of listeners list
      child: BlocBuilder<ProviderBloc, ProviderState>(
        builder: (context, state) {
          // Find the booking from loaded state
        if (state is ProviderLoaded) {
          _booking = [...state.activeBookings, ...state.pendingBookings]
              .cast<BookingEntity?>()
              .firstWhere((b) => b?.id == widget.bookingId, orElse: () => null);
        }

        // Use widget.bookingStatus if _booking is null
        final currentStatus = _booking?.status ?? widget.bookingStatus ?? 'in_progress';

        final isLoading = state is ProviderBookingActionInProgress &&
            state.bookingId == widget.bookingId;

        return Scaffold(
          body: Stack(
            children: [
              // Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.pickupLocation ?? const LatLng(31.5204, 74.3587),
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.haulistry.app',
                  ),
                  PolylineLayer(polylines: _polylines),
                  MarkerLayer(markers: _markers),
                ],
              ),

              // Top bar with back button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Text(
                            widget.serviceType?.toUpperCase() ?? 'TRACKING',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom controls
              Positioned(
                right: 16,
                bottom: 200,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(_autoFollowSeeker ? Icons.gps_fixed : Icons.gps_not_fixed),
                        onPressed: () {
                          setState(() {
                            _autoFollowSeeker = !_autoFollowSeeker;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: _centerOnCurrentLocation,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.route),
                        onPressed: _fitMapToRoute,
                      ),
                    ),
                  ],
                ),
              ),

              // Floating communication shortcuts
              if (_isActiveServiceStatus)
                Positioned(
                  right: 16,
                  bottom: 280,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'provider_track_call',
                        backgroundColor: AppTheme.secondaryColor,
                        onPressed: () {
                          final seekerId = _booking?.seekerId;
                          final seekerName = _booking?.seekerName;
                          if (seekerId != null) {
                            context.read<CallBloc>().add(
                              InitiateCallRequested(
                                receiverId: seekerId,
                                receiverName: seekerName ?? 'Seeker',
                                receiverRole: 'seeker',
                                bookingId: widget.bookingId,
                                callType: 'voice',
                              ),
                            );
                            context.push('/call/outgoing', extra: {
                              'callId': 'pending',
                              'receiverName': seekerName ?? 'Seeker',
                              'receiverRole': 'seeker',
                              'callType': 'voice',
                            });
                          }
                        },
                        child: const Icon(Icons.call_rounded, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton.small(
                        heroTag: 'provider_track_message',
                        backgroundColor: AppTheme.accentColor,
                        onPressed: () {
                          final seekerId = _booking?.seekerId;
                          final seekerName = _booking?.seekerName;
                          if (seekerId != null) {
                            context.push('/chat', extra: {
                              'otherUserId': seekerId,
                              'otherUserName': seekerName ?? 'Seeker',
                              'bookingId': widget.bookingId,
                            });
                          }
                        },
                        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),

              // Bottom info panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Locations
                      if (widget.pickupAddress != null)
                        _buildLocationRow(
                          icon: Icons.trip_origin,
                          color: AppTheme.successColor,
                          label: 'Pickup',
                          address: widget.pickupAddress!,
                        ),
                      if (widget.pickupAddress != null && widget.dropAddress != null)
                        const SizedBox(height: 12),
                      if (widget.dropAddress != null)
                        _buildLocationRow(
                          icon: Icons.location_on,
                          color: AppTheme.errorColor,
                          label: 'Drop-off',
                          address: widget.dropAddress!,
                        ),

                      const SizedBox(height: 20),

                      // Proximity indicator
                      if (currentStatus == 'in_progress')
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: _isNearDropLocation
                                ? AppTheme.successColor.withOpacity(0.1)
                                : AppTheme.warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isNearDropLocation
                                  ? AppTheme.successColor.withOpacity(0.3)
                                  : AppTheme.warningColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isNearDropLocation ? Icons.check_circle : Icons.near_me,
                                color: _isNearDropLocation
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isNearDropLocation
                                      ? 'You are at the drop-off location!'
                                      : 'Navigate to the drop-off location',
                                  style: TextStyle(
                                    color: _isNearDropLocation
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Communication Buttons (Call & Message)
                      if (_isActiveServiceStatus) ...[
                        Row(
                          children: [
                            // Call Button
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.secondaryGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.secondaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      // Initiate voice call
                                      final seekerId = _booking?.seekerId;
                                      final seekerName = _booking?.seekerName;
                                      if (seekerId != null) {
                                        context.read<CallBloc>().add(
                                          InitiateCallRequested(
                                            receiverId: seekerId,
                                            receiverName: seekerName ?? 'Seeker',
                                            receiverRole: 'seeker',
                                            bookingId: widget.bookingId,
                                            callType: 'voice',
                                          ),
                                        );
                                        context.push('/call/outgoing', extra: {
                                          'callId': 'pending',
                                          'receiverName': seekerName ?? 'Seeker',
                                          'receiverRole': 'seeker',
                                          'callType': 'voice',
                                        });
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Seeker information not available')),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.phone, color: Colors.white, size: 22),
                                        SizedBox(width: 8),
                                        Text(
                                          'Call',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Video Call Button
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    // Initiate video call
                                    final seekerId = _booking?.seekerId;
                                    final seekerName = _booking?.seekerName;
                                    if (seekerId != null) {
                                      context.read<CallBloc>().add(
                                        InitiateCallRequested(
                                          receiverId: seekerId,
                                          receiverName: seekerName ?? 'Seeker',
                                          receiverRole: 'seeker',
                                          bookingId: widget.bookingId,
                                          callType: 'video',
                                        ),
                                      );
                                      context.push('/call/outgoing', extra: {
                                        'callId': 'pending',
                                        'receiverName': seekerName ?? 'Seeker',
                                        'receiverRole': 'seeker',
                                        'callType': 'video',
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Seeker information not available')),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: const Icon(Icons.videocam, color: Colors.white, size: 26),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Message Button
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.accentGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      // Navigate to chat screen
                                      final seekerId = _booking?.seekerId;
                                      final seekerName = _booking?.seekerName;
                                      if (seekerId != null) {
                                        context.push('/chat', extra: {
                                          'otherUserId': seekerId,
                                          'otherUserName': seekerName ?? 'Seeker',
                                          'bookingId': widget.bookingId,
                                        });
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.chat_bubble, color: Colors.white, size: 22),
                                        SizedBox(width: 8),
                                        Text(
                                          'Message',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Complete button - show for active bookings
                      if (currentStatus == 'in_progress' ||
                          currentStatus == 'provider_arrived' ||
                          currentStatus == 'accepted' ||
                          currentStatus == 'provider_arriving')
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : _completeBooking,
                            icon: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_rounded),
                            label: Text(
                              isLoading ? 'Completing...' : 'Complete Booking',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ), // End of BlocBuilder (child of MultiBlocListener)
  ); // End of MultiBlocListener (return statement)
} // End of build method

Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
