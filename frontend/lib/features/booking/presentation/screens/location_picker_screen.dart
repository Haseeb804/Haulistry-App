import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

// ─── Result type ─────────────────────────────────────────────────────────────

class LocationPickerResult {
  final LatLng location;
  final String address;

  const LocationPickerResult({required this.location, required this.address});
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class LocationPickerScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final LatLng? initialLocation;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with TickerProviderStateMixin {
  // ── Map ──────────────────────────────────────────────────────────────────
  final MapController _mapController = MapController();
  static const LatLng _defaultCenter = LatLng(31.5204, 74.3587); // Lahore

  LatLng? _selectedLocation;
  String? _selectedAddress;

  // ── Search ───────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<_SearchResult> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounce;

  // ── State flags ──────────────────────────────────────────────────────────
  bool _locating = false;
  bool _geocoding = false;
  bool _searching = false;

  // ── Pin drop animation ───────────────────────────────────────────────────
  late AnimationController _pinBounceCtrl;
  late Animation<double> _pinBounce;
  late AnimationController _rippleCtrl;
  late Animation<double> _ripple;

  // ── Bottom sheet ─────────────────────────────────────────────────────────
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  static const double _sheetMin = 0.13;
  static const double _sheetPeek = 0.28;

  @override
  void initState() {
    super.initState();

    _pinBounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pinBounce = Tween<double>(begin: 0, end: -16).animate(
      CurvedAnimation(parent: _pinBounceCtrl, curve: Curves.elasticOut),
    );

    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _ripple = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );

    _selectedLocation = widget.initialLocation ?? _defaultCenter;
    if (widget.initialLocation != null) {
      _reverseGeocode(widget.initialLocation!);
    } else {
      _gotoCurrentLocation();
    }

    _searchController.addListener(_onSearchChanged);
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    _pinBounceCtrl.dispose();
    _rippleCtrl.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _sheetCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Location logic ────────────────────────────────────────────────────────

  Future<void> _gotoCurrentLocation() async {
    setState(() => _locating = true);
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _snack('Location services are disabled');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final loc = LatLng(pos.latitude, pos.longitude);
      _setLocation(loc, animate: true);
    } catch (_) {
      _snack('Could not get current location');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _setLocation(LatLng loc, {bool animate = false}) {
    setState(() {
      _selectedLocation = loc;
      _selectedAddress = null;
    });
    if (animate) {
      _mapController.move(loc, 15);
    }
    _dropPin();
    _reverseGeocode(loc);
    _sheetCtrl.animateTo(_sheetPeek,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  void _dropPin() {
    _pinBounceCtrl
      ..reset()
      ..forward();
    _rippleCtrl
      ..reset()
      ..forward();
    HapticFeedback.lightImpact();
  }

  Future<void> _reverseGeocode(LatLng loc) async {
    setState(() => _geocoding = true);
    try {
      final url = Uri.parse(
        '${MapEndpoints.nominatimReverse}?'
        'format=json&lat=${loc.latitude}&lon=${loc.longitude}'
        '&zoom=18&addressdetails=1',
      );
      final res = await http
          .get(url, headers: {'User-Agent': MapEndpoints.userAgent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['display_name'] != null && mounted) {
          setState(() => _selectedAddress = data['display_name'] as String);
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _selectedAddress =
          '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}');
    }
  }

  // ── Search logic ──────────────────────────────────────────────────────────

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchController.text.trim();
    if (q.length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _fetchSuggestions(q));
  }

  Future<void> _fetchSuggestions(String q) async {
    setState(() => _searching = true);
    try {
      final url = Uri.parse(
        '${MapEndpoints.nominatimSearch}?format=json&q=${Uri.encodeQueryComponent(q)}&limit=5',
      );
      final res = await http
          .get(url, headers: {'User-Agent': MapEndpoints.userAgent})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body) as List;
        if (mounted) {
          setState(() {
            _suggestions = list
                .map((e) => _SearchResult(
                      displayName: e['display_name'] as String,
                      lat: double.parse(e['lat'] as String),
                      lon: double.parse(e['lon'] as String),
                    ))
                .toList();
            _showSuggestions = _suggestions.isNotEmpty;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  void _selectSuggestion(_SearchResult r) {
    final loc = LatLng(r.lat, r.lon);
    _searchController.text = _shortAddress(r.displayName);
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _selectedAddress = r.displayName;
    });
    _selectedLocation = loc;
    _mapController.move(loc, 15);
    _dropPin();
    _sheetCtrl.animateTo(_sheetPeek,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  String _shortAddress(String full) {
    final parts = full.split(', ');
    return parts.take(3).join(', ');
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

  void _confirm() {
    if (_selectedLocation == null) return;
    final addr = _selectedAddress ??
        '${_selectedLocation!.latitude.toStringAsFixed(5)}, '
            '${_selectedLocation!.longitude.toStringAsFixed(5)}';
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      LocationPickerResult(location: _selectedLocation!, address: addr),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Full-screen map ───────────────────────────────────────────────
          _buildMap(),

          // ── Top search bar ────────────────────────────────────────────────
          _buildTopBar(),

          // ── Search suggestions overlay ────────────────────────────────────
          if (_showSuggestions) _buildSuggestionsOverlay(),

          // ── Right-side controls ───────────────────────────────────────────
          _buildSideControls(),

          // ── Draggable bottom sheet ────────────────────────────────────────
          _buildBottomSheet(),
        ],
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _selectedLocation ?? _defaultCenter,
        initialZoom: 14,
        onTap: (_, latLng) => _setLocation(latLng),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapEndpoints.osmTileTemplate,
          userAgentPackageName: 'com.haulistry.app',
          tileBuilder: (context, widget, tile) => widget,
        ),
        if (_selectedLocation != null) _buildMarkerLayer(),
      ],
    );
  }

  Widget _buildMarkerLayer() {
    return MarkerLayer(
      markers: [
        Marker(
          point: _selectedLocation!,
          width: 80,
          height: 100,
          alignment: Alignment.bottomCenter,
          child: _buildAnimatedPin(),
        ),
      ],
    );
  }

  Widget _buildAnimatedPin() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pinBounce, _ripple]),
      builder: (_, __) {
        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Ripple shadow
            Positioned(
              bottom: 0,
              child: Transform.scale(
                scale: 0.4 + _ripple.value * 0.6,
                child: Opacity(
                  opacity: (1 - _ripple.value).clamp(0, 1),
                  child: Container(
                    width: 48,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: AppTheme.primaryColor.withOpacity(0.35),
                    ),
                  ),
                ),
              ),
            ),
            // Shadow dot (static)
            Positioned(
              bottom: 0,
              child: Container(
                width: 12,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: Colors.black.withOpacity(0.2),
                ),
              ),
            ),
            // Pin
            Transform.translate(
              offset: Offset(0, _pinBounce.value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 24),
                  ),
                  // Pin tail
                  CustomPaint(
                    size: const Size(14, 10),
                    painter: _PinTailPainter(color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Top search bar ────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                            shadows: [
                              Shadow(
                                  color: Colors.white54,
                                  offset: Offset(0, 1),
                                  blurRadius: 4),
                            ],
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF555577),
                              shadows: [
                                Shadow(
                                    color: Colors.white70,
                                    offset: Offset(0, 1),
                                    blurRadius: 3),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search bar
              _SearchBar(
                controller: _searchController,
                focusNode: _searchFocus,
                isLoading: _searching,
                onClear: () {
                  _searchController.clear();
                  setState(() {
                    _suggestions = [];
                    _showSuggestions = false;
                  });
                },
                onSubmitted: (q) {
                  if (q.trim().isNotEmpty) _fetchSuggestions(q.trim());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Suggestions overlay ───────────────────────────────────────────────────

  Widget _buildSuggestionsOverlay() {
    final topOffset = MediaQuery.of(context).padding.top + 12 + 44 + 12 + 52 + 8;
    return Positioned(
      top: topOffset,
      left: 16,
      right: 16,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black26,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < _suggestions.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 52, color: Colors.grey.shade100),
                _SuggestionTile(
                  result: _suggestions[i],
                  onTap: () => _selectSuggestion(_suggestions[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Side controls (GPS + zoom) ────────────────────────────────────────────

  Widget _buildSideControls() {
    return Positioned(
      right: 16,
      bottom: MediaQuery.of(context).size.height * _sheetPeek + 16,
      child: Column(
        children: [
          _CircleButton(
            icon: Icons.my_location_rounded,
            isLoading: _locating,
            onTap: _gotoCurrentLocation,
          ),
          const SizedBox(height: 10),
          _ZoomControls(mapController: _mapController),
        ],
      ),
    );
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────

  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      controller: _sheetCtrl,
      initialChildSize: _sheetMin,
      minChildSize: _sheetMin,
      maxChildSize: 0.45,
      snap: true,
      snapSizes: const [_sheetMin, _sheetPeek],
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Location row ────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: _selectedLocation != null
                                  ? AppTheme.primaryGradient
                                  : const LinearGradient(colors: [
                                      Color(0xFFBDBDBD),
                                      Color(0xFF9E9E9E)
                                    ]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.location_on_rounded,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selected Location',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                if (_geocoding)
                                  _ShimmerPlaceholder()
                                else if (_selectedAddress != null)
                                  Text(
                                    _selectedAddress!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1A1A2E),
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else
                                  const Text(
                                    'Tap on the map to select a location',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (_selectedLocation != null) ...[
                        const SizedBox(height: 12),
                        // Coordinates badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.gps_fixed_rounded,
                                  size: 13,
                                  color: AppTheme.primaryColor
                                      .withOpacity(0.7)),
                              const SizedBox(width: 6),
                              Text(
                                '${_selectedLocation!.latitude.toStringAsFixed(5)}, '
                                '${_selectedLocation!.longitude.toStringAsFixed(5)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color:
                                      AppTheme.primaryColor.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // ── Confirm button ─────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _selectedLocation != null ? 1 : 0.45,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: _selectedLocation != null
                                  ? AppTheme.primaryGradient
                                  : const LinearGradient(colors: [
                                      Color(0xFFCCCCCC),
                                      Color(0xFFBBBBBB)
                                    ]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _selectedLocation != null
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                            ),
                            child: TextButton.icon(
                              onPressed:
                                  _selectedLocation != null ? _confirm : null,
                              icon: const Icon(Icons.check_circle_rounded,
                                  color: Colors.white, size: 20),
                              label: const Text(
                                'Confirm Location',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Pin tail painter ─────────────────────────────────────────────────────────

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}

// ─── Search bar widget ────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onClear,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                )
              : Icon(Icons.search_rounded,
                  size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF1A1A2E)),
              decoration: const InputDecoration(
                hintText: 'Search city, area, street...',
                hintStyle:
                    TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded,
                    size: 14, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Suggestion tile ──────────────────────────────────────────────────────────

class _SearchResult {
  final String displayName;
  final double lat;
  final double lon;
  const _SearchResult(
      {required this.displayName, required this.lat, required this.lon});
}

class _SuggestionTile extends StatelessWidget {
  final _SearchResult result;
  final VoidCallback onTap;

  const _SuggestionTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final parts = result.displayName.split(', ');
    final main = parts.first;
    final sub = parts.skip(1).take(3).join(', ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.place_rounded,
                  size: 16, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(main,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E))),
                  if (sub.isNotEmpty)
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Circle button ────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isLoading
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryColor),
              )
            : Icon(icon, size: 20, color: const Color(0xFF1A1A2E)),
      ),
    );
  }
}

// ─── Zoom controls ────────────────────────────────────────────────────────────

class _ZoomControls extends StatelessWidget {
  final MapController mapController;
  const _ZoomControls({required this.mapController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _ZoomBtn(
            icon: Icons.add_rounded,
            isTop: true,
            onTap: () => mapController.move(
                mapController.camera.center, mapController.camera.zoom + 1),
          ),
          Container(height: 1, color: Colors.grey.shade100),
          _ZoomBtn(
            icon: Icons.remove_rounded,
            isTop: false,
            onTap: () => mapController.move(
                mapController.camera.center, mapController.camera.zoom - 1),
          ),
        ],
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final bool isTop;
  final VoidCallback onTap;
  const _ZoomBtn(
      {required this.icon, required this.isTop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isTop ? const Radius.circular(14) : Radius.zero,
        bottom: isTop ? Radius.zero : const Radius.circular(14),
      ),
      child: SizedBox(
        width: 44,
        height: 40,
        child: Icon(icon, size: 20, color: const Color(0xFF1A1A2E)),
      ),
    );
  }
}

// ─── Shimmer placeholder ──────────────────────────────────────────────────────

class _ShimmerPlaceholder extends StatefulWidget {
  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.9).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in [double.infinity, 180.0, 120.0]) ...[
            Container(
              height: 12,
              width: w,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(_anim.value),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
