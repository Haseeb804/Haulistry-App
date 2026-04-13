import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../feedback/data/datasources/feedback_remote_datasource.dart';
import '../../../feedback/data/repositories/feedback_repository_impl.dart';
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
  final MapController _mapController = MapController();
  final FeedbackRepositoryImpl _feedbackRepository = FeedbackRepositoryImpl(
    remoteDataSource: FeedbackRemoteDataSource(baseUrl: AppConstants.apiUrl),
  );

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  List<LatLng> _routePoints = [];

  LatLng? _providerDisplayLocation;
  double _providerSpeedKmh = 0;
  bool _autoFollowProvider = true;
  bool _isTrackingActive = false;
  bool _feedbackRedirectChecked = false;

  Timer? _markerAnimationTimer;

  bool get _isActiveServiceStatus {
    final status = (widget.bookingStatus ?? '').toLowerCase();
    if (status == 'confirmed') return true;
    return status == 'accepted' ||
        status == 'provider_arriving' ||
        status == 'provider_arrived' ||
        status == 'in_progress';
  }

  bool get _isCompletedServiceStatus {
    final status = (widget.bookingStatus ?? '').toLowerCase();
    return status == 'completed';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isActiveServiceStatus) {
        _checkMandatorySeekerFeedback();
        return;
      }
      _setupMap();
      _startLocationTracking();
    });
  }

  Future<void> _checkMandatorySeekerFeedback() async {
    if (_feedbackRedirectChecked || !_isCompletedServiceStatus) return;
    _feedbackRedirectChecked = true;

    if (widget.providerId.isEmpty) return;

    try {
      final exists = await _feedbackRepository.checkFeedbackExists(widget.bookingId, 'seeker');
      if (!mounted || exists) return;

      context.go('/feedback/seeker', extra: {
        'bookingId': widget.bookingId,
        'providerId': widget.providerId,
        'providerName': widget.providerName ?? 'Provider',
      });
    } catch (_) {
      // If check fails, keep fallback unavailable UI and avoid breaking flow.
    }
  }

  @override
  void dispose() {
    _markerAnimationTimer?.cancel();
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
      setState(() {});
    }
  }

  void _setupMap() {
    _updateMarkers();
    _fetchRoute();
  }

  void _animateProviderMarkerTo(LatLng target) {
    _markerAnimationTimer?.cancel();

    final start = _providerDisplayLocation;
    if (start == null) {
      _providerDisplayLocation = target;
      _updateMarkers();
      return;
    }

    const steps = 14;
    var step = 0;

    _markerAnimationTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      step++;
      final t = Curves.easeOutCubic.transform(step / steps);
      final lat = start.latitude + (target.latitude - start.latitude) * t;
      final lng = start.longitude + (target.longitude - start.longitude) * t;

      setState(() {
        _providerDisplayLocation = LatLng(lat, lng);
      });
      _updateMarkers();

      if (step >= steps) {
        timer.cancel();
      }
    });
  }

  void _onProviderLocationUpdate(LocationData providerLoc) {
    final target = LatLng(providerLoc.latitude, providerLoc.longitude);
    _providerSpeedKmh = providerLoc.speed ?? _providerSpeedKmh;

    _animateProviderMarkerTo(target);

    if (_autoFollowProvider && _providerDisplayLocation != null) {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_providerDisplayLocation!, currentZoom < 14 ? 14 : currentZoom);
    }
  }

  void _updateMarkers() {
    final markers = <Marker>[];

    if (widget.pickupLocation != null) {
      markers.add(
        Marker(
          point: widget.pickupLocation!,
          width: 52,
          height: 52,
          child: _buildPin(Icons.trip_origin, AppTheme.secondaryGradient),
        ),
      );
    }

    if (widget.dropoffLocation != null) {
      markers.add(
        Marker(
          point: widget.dropoffLocation!,
          width: 52,
          height: 52,
          child: _buildPin(Icons.location_on_rounded, AppTheme.primaryGradient),
        ),
      );
    }

    if (_providerDisplayLocation != null) {
      markers.add(
        Marker(
          point: _providerDisplayLocation!,
          width: 68,
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
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

  Widget _buildPin(IconData icon, LinearGradient gradient) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
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

          _routePoints = coordinates
              .map((coord) => LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble()))
              .toList();

          _polylines = [
            Polyline(
              points: _routePoints,
              color: AppTheme.accentColor,
              strokeWidth: 5,
            ),
          ];

          setState(() {});
          _fitMapToRoute();
          return;
        }
      }
    } catch (_) {}

    _routePoints = [widget.pickupLocation!, widget.dropoffLocation!];
    _polylines = [
      Polyline(
        points: _routePoints,
        color: AppTheme.accentColor,
        strokeWidth: 5,
      ),
    ];
    setState(() {});
    _fitMapToRoute();
  }

  void _fitMapToRoute() {
    final points = <LatLng>[];
    if (widget.pickupLocation != null) points.add(widget.pickupLocation!);
    if (widget.dropoffLocation != null) points.add(widget.dropoffLocation!);
    if (_providerDisplayLocation != null) points.add(_providerDisplayLocation!);
    if (points.isEmpty) return;

    final minLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    final bounds = LatLngBounds(
      LatLng(minLat - 0.008, minLng - 0.008),
      LatLng(maxLat + 0.008, maxLng + 0.008),
    );

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.fromLTRB(40, 120, 40, 250)),
    );
  }

  double _distanceKmToDrop() {
    if (_providerDisplayLocation != null && widget.dropoffLocation != null) {
      final m = Geolocator.distanceBetween(
        _providerDisplayLocation!.latitude,
        _providerDisplayLocation!.longitude,
        widget.dropoffLocation!.latitude,
        widget.dropoffLocation!.longitude,
      );
      return m / 1000;
    }

    if (widget.pickupLocation != null && widget.dropoffLocation != null) {
      final m = Geolocator.distanceBetween(
        widget.pickupLocation!.latitude,
        widget.pickupLocation!.longitude,
        widget.dropoffLocation!.latitude,
        widget.dropoffLocation!.longitude,
      );
      return m / 1000;
    }

    return 0;
  }

  int _etaMinutes(double distanceKm) {
    final speed = _providerSpeedKmh > 5 ? _providerSpeedKmh : 30;
    final eta = ((distanceKm / speed) * 60).ceil();
    return eta < 1 ? 1 : eta;
  }

  String _statusText(double distanceKm) {
    final status = (widget.bookingStatus ?? '').toLowerCase();
    if (status == 'completed') return 'Completed';
    if (status == 'cancelled') return 'Cancelled';
    if (status == 'provider_arrived' || distanceKm < 0.10) return 'Arrived';
    return 'On the way';
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'arrived') return AppTheme.successColor;
    if (normalized == 'completed') return AppTheme.successColor;
    if (normalized == 'cancelled') return AppTheme.errorColor;
    return AppTheme.warningColor;
  }

  void _callProvider() {
    if (widget.providerId.isEmpty) return;

    context.read<CallBloc>().add(
          InitiateCallRequested(
            receiverId: widget.providerId,
            receiverName: widget.providerName ?? 'Provider',
            receiverRole: 'provider',
            bookingId: widget.bookingId,
            callType: 'voice',
          ),
        );

    context.push('/call/outgoing', extra: {
      'callId': 'pending',
      'receiverName': widget.providerName ?? 'Provider',
      'receiverRole': 'provider',
      'callType': 'voice',
    });
  }

  void _messageProvider() {
    context.push('/chat', extra: {
      'otherUserId': widget.providerId,
      'otherUserName': widget.providerName ?? 'Provider',
      'bookingId': widget.bookingId,
    });
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
                      color: AppTheme.errorColor.withValues(alpha: 0.12),
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
                      onPressed: () => context.go('/seeker/history'),
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

    final distanceKm = _distanceKmToDrop();
    final etaMin = _etaMinutes(distanceKm);
    final status = _statusText(distanceKm);
    final statusColor = _statusColor(status);

    return BlocListener<LocationTrackingBloc, LocationTrackingState>(
      listener: (context, state) {
        if (state is LocationTrackingActive) {
          final other = state.otherUserLocation;
          if (other != null) {
            _onProviderLocationUpdate(other);
          }
        } else if (state is LocationTrackingErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppTheme.errorColor),
          );
        } else if (state is LocationPermissionDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required for tracking'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
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
                PolylineLayer(polylines: _polylines),
                MarkerLayer(markers: _markers),
              ],
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    _circleGlassButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.go('/seeker/home'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isTrackingActive ? AppTheme.successColor : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Live Tracking',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                            Text(
                              _isTrackingActive ? 'LIVE' : 'OFF',
                              style: TextStyle(
                                color: _isTrackingActive ? AppTheme.successColor : Colors.grey,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              right: 16,
              top: 120,
              child: Column(
                children: [
                  _circleGlassButton(
                    icon: _autoFollowProvider ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                    onTap: () => setState(() => _autoFollowProvider = !_autoFollowProvider),
                  ),
                  const SizedBox(height: 10),
                  _circleGlassButton(
                    icon: Icons.route_rounded,
                    onTap: _fitMapToRoute,
                  ),
                ],
              ),
            ),

            if (_isActiveServiceStatus)
              Positioned(
                right: 16,
                bottom: 190,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'track_call_provider',
                      onPressed: _callProvider,
                      backgroundColor: AppTheme.secondaryColor,
                      child: const Icon(Icons.call_rounded, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      heroTag: 'track_message_provider',
                      onPressed: _messageProvider,
                      backgroundColor: AppTheme.accentColor,
                      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: const Icon(Icons.person_rounded, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.providerName ?? 'Provider',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                widget.serviceType ?? 'Service',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _metricChip(Icons.straighten_rounded, '${distanceKm.toStringAsFixed(1)} km'),
                        const SizedBox(width: 10),
                        _metricChip(Icons.schedule_rounded, '~$etaMin min'),
                        const SizedBox(width: 10),
                        _metricChip(
                          Icons.payments_rounded,
                          'Rs ${widget.estimatedPrice?.toStringAsFixed(0) ?? '0'}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleGlassButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppTheme.textPrimary),
        ),
      ),
    );
  }

  Widget _metricChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
