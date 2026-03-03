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
import '../../../call/presentation/bloc/call_bloc.dart';
import '../../../call/presentation/bloc/call_event.dart';
import '../bloc/location_tracking_bloc.dart';
import '../bloc/location_tracking_event.dart';
import '../bloc/location_tracking_state.dart';

class TrackingScreen extends StatefulWidget {
  final String bookingId;
  final String providerId;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final String? pickupAddress;
  final String? dropAddress;
  final double? estimatedPrice;
  final String? serviceType;
  final String? bookingStatus;
  final String? providerName;
  final String? seekerName;

  const TrackingScreen({
    super.key,
    required this.bookingId,
    required this.providerId,
    this.pickupLocation,
    this.dropoffLocation,
    this.pickupAddress,
    this.dropAddress,
    this.estimatedPrice,
    this.serviceType,
    this.bookingStatus,
    this.providerName,
    this.seekerName,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  MapController? _mapController;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  List<LatLng> _routePoints = [];
  LatLng? _providerLocation; // Real-time provider location
  bool _isTrackingActive = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupMap();
      _startLocationTracking();
    });
  }

  @override
  void dispose() {
    // Stop tracking when leaving screen
    context.read<LocationTrackingBloc>().add(const StopLocationTracking());
    super.dispose();
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
      _isTrackingActive = true;
    }
  }

  void _setupMap() {
    _updateMarkers();
    _fetchRoute();
  }

  void _updateMarkers() {
    List<Marker> markers = [];
    
    // Pickup location marker (static)
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
    
    // Dropoff location marker (static)
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
    
    // Provider real-time location marker (dynamic)
    if (_providerLocation != null) {
      markers.add(
        Marker(
          point: _providerLocation!,
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

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _fetchRoute() async {
    if (widget.pickupLocation == null || widget.dropoffLocation == null) return;

    try {
      // Use OSRM free routing API to get actual road route
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

          // Fit map to show entire route
          _fitMapToRoute();
          return;
        }
      }
    } catch (e) {
    }

    // Fallback to straight line if OSRM fails
    setState(() {
      _routePoints = [widget.pickupLocation!, widget.dropoffLocation!];
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

  void _fitMapToRoute() {
    if (widget.pickupLocation == null || widget.dropoffLocation == null) return;
    
    // Calculate bounds
    final minLat = widget.pickupLocation!.latitude < widget.dropoffLocation!.latitude 
        ? widget.pickupLocation!.latitude : widget.dropoffLocation!.latitude;
    final maxLat = widget.pickupLocation!.latitude > widget.dropoffLocation!.latitude 
        ? widget.pickupLocation!.latitude : widget.dropoffLocation!.latitude;
    final minLng = widget.pickupLocation!.longitude < widget.dropoffLocation!.longitude 
        ? widget.pickupLocation!.longitude : widget.dropoffLocation!.longitude;
    final maxLng = widget.pickupLocation!.longitude > widget.dropoffLocation!.longitude 
        ? widget.pickupLocation!.longitude : widget.dropoffLocation!.longitude;
    
    // Add padding
    final latPadding = (maxLat - minLat) * 0.2;
    final lngPadding = (maxLng - minLng) * 0.2;
    
    final bounds = LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
    
    _mapController?.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }

  @override
  Widget build(BuildContext context) {
    final totalDistance = (widget.pickupLocation != null && widget.dropoffLocation != null)
        ? Geolocator.distanceBetween(
            widget.pickupLocation!.latitude,
            widget.pickupLocation!.longitude,
            widget.dropoffLocation!.latitude,
            widget.dropoffLocation!.longitude,
          ) / 1000
        : 0.0;

    return BlocListener<LocationTrackingBloc, LocationTrackingState>(
      listener: (context, state) {
        if (state is LocationTrackingActive) {
          // Update provider location from real-time data
          final otherUserLoc = state.otherUserLocation;
          if (otherUserLoc != null) {
            setState(() {
              _providerLocation = LatLng(otherUserLoc.latitude, otherUserLoc.longitude);
            });
            _updateMarkers();
            
            // Optionally center on provider location
            if (_providerLocation != null) {
              _mapController?.move(_providerLocation!, 14);
            }
          }
        } else if (state is LocationTrackingErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location tracking error: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state is LocationPermissionDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required for tracking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: Stack(
          children: [
            // OpenStreetMap - Full Screen
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.pickupLocation ?? const LatLng(31.5204, 74.3587),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.haulistry.app',
                ),
                PolylineLayer(
                  polylines: _polylines,
                ),
                MarkerLayer(
                  markers: _markers,
                ),
              ],
            ),

            // Real-time tracking indicator
            if (_isTrackingActive)
              Positioned(
                top: 60,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Live Tracking',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Top App Bar with gradient styling
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.go('/seeker/home'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: AppTheme.secondaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.secondaryColor.withOpacity(0.3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Live Tracking',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'LIVE',
                              style: TextStyle(
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.center_focus_strong, color: Colors.white),
                      onPressed: _fitMapToRoute,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Modern Draggable Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.30,
            minChildSize: 0.15,
            maxChildSize: 0.65,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Service Badge & Stats Row
                        Row(
                          children: [
                            if (widget.serviceType != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_shipping, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.serviceType!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const Spacer(),
                            _buildCompactStat(Icons.straighten, '${totalDistance.toStringAsFixed(1)} km', AppTheme.secondaryGradient),
                            const SizedBox(width: 10),
                            _buildCompactStat(Icons.payments, 'Rs ${widget.estimatedPrice?.toStringAsFixed(0) ?? '0'}', AppTheme.accentGradient),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Modern Route Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              _buildLocationItem('Pickup', widget.pickupAddress ?? 'Not available', AppTheme.secondaryGradient),
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 2,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildLocationItem('Drop', widget.dropAddress ?? 'Not available', AppTheme.primaryGradient),
                            ],
                          ),
                        ),
                        
                        // Booking Status Display
                        if (widget.bookingStatus != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: _getStatusGradient(widget.bookingStatus!),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatusColor(widget.bookingStatus!).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getStatusIcon(widget.bookingStatus!),
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Booking Status',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.bookingStatus!.replaceAll('_', ' ').toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Communication Buttons (Call & Message)
                        if (widget.bookingStatus != 'completed' && widget.bookingStatus != 'cancelled') ...[
                          const SizedBox(height: 20),
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
                                        // Initiate voice call through CallBloc
                                        if (widget.providerId.isNotEmpty) {
                                          context.read<CallBloc>().add(
                                            InitiateCallRequested(
                                              receiverId: widget.providerId,
                                              receiverName: widget.providerName ?? 'Provider',
                                              receiverRole: 'provider',
                                              bookingId: widget.bookingId,
                                              callType: 'voice',
                                            ),
                                          );
                                          // Navigate to outgoing call screen
                                          context.push('/call/outgoing', extra: {
                                            'callId': 'pending',
                                            'receiverName': widget.providerName ?? 'Provider',
                                            'receiverRole': 'provider',
                                            'callType': 'voice',
                                          });
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Provider information not available')),
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
                                      // Initiate video call through CallBloc
                                      if (widget.providerId.isNotEmpty) {
                                        context.read<CallBloc>().add(
                                          InitiateCallRequested(
                                            receiverId: widget.providerId,
                                            receiverName: widget.providerName ?? 'Provider',
                                            receiverRole: 'provider',
                                            bookingId: widget.bookingId,
                                            callType: 'video',
                                          ),
                                        );
                                        // Navigate to outgoing call screen
                                        context.push('/call/outgoing', extra: {
                                          'callId': 'pending',
                                          'receiverName': widget.providerName ?? 'Provider',
                                          'receiverRole': 'provider',
                                          'callType': 'video',
                                        });
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Provider information not available')),
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
                                        context.push('/chat', extra: {
                                          'otherUserId': widget.providerId,
                                          'otherUserName': widget.providerName ?? 'Provider',
                                          'bookingId': widget.bookingId,
                                        });
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
                        ],
                        
                        // Rate Service Button for Completed Bookings
                        if (widget.bookingStatus == 'completed') ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                context.push('/feedback/seeker', extra: {
                                  'bookingId': widget.bookingId,
                                  'providerId': widget.providerId,
                                  'providerName': widget.providerName ?? 'Provider',
                                });
                              },
                              icon: const Icon(Icons.star_rounded),
                              label: const Text(
                                'Rate Service',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ), // End of Scaffold (child of BlocListener)
  ); // End of BlocListener (return statement)
} // End of build method

Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppTheme.successColor;
      case 'in_progress':
      case 'accepted':
      case 'provider_arriving':
      case 'provider_arrived':
        return AppTheme.primaryColor;
      case 'pending':
        return AppTheme.warningColor;
      case 'cancelled':
      case 'rejected':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  LinearGradient _getStatusGradient(String status) {
    final color = _getStatusColor(status);
    return LinearGradient(
      colors: [color, color.withOpacity(0.7)],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
      case 'provider_arriving':
      case 'provider_arrived':
        return Icons.local_shipping;
      case 'accepted':
        return Icons.thumb_up;
      case 'pending':
        return Icons.schedule;
      case 'cancelled':
        return Icons.cancel;
      case 'rejected':
        return Icons.block;
      default:
        return Icons.info;
    }
  }

  Widget _buildCompactStat(IconData icon, String value, LinearGradient gradient) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient.colors.first.withOpacity(0.1),
            gradient.colors.last.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: gradient.colors.first),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: gradient.colors.first),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem(String label, String address, LinearGradient gradient) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            gradient: gradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                address,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient.colors.first.withOpacity(0.1),
            gradient.colors.last.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: gradient.colors.first,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
