import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../services/domain/entities/service_entity.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import 'location_picker_screen.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class BookingRequestScreen extends StatefulWidget {
  final ServiceEntity service;

  const BookingRequestScreen({super.key, required this.service});

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  final _notesController = TextEditingController();
  final _scrollController = ScrollController();
  final _mapController = MapController();
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingBloc>().add(BookingServiceSelected(
            serviceType: widget.service.category,
            service: widget.service,
          ));
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Map helpers ────────────────────────────────────────────────────────────

  void _fitMapToLocations(BookingInProgress state) {
    if (!_mapReady) return;
    final pts = <LatLng>[
      if (state.pickupLocation != null) state.pickupLocation!,
      if (state.dropLocation != null) state.dropLocation!,
    ];
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _mapController.move(pts.first, 13);
      return;
    }
    final minLat = pts.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = pts.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng = pts.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng = pts.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 10);
  }

  // ── Location picking ───────────────────────────────────────────────────────

  Future<void> _pickLocation({
    required String title,
    required String subtitle,
    required LatLng? initialLocation,
    required bool isPickup,
    required bool isWorkSite,
  }) async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LocationPickerScreen(
          title: title,
          subtitle: subtitle,
          initialLocation: initialLocation,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final bloc = context.read<BookingBloc>();
    if (isWorkSite) {
      bloc.add(BookingWorkLocationSelected(
        location: result.location,
        address: result.address,
      ));
    } else if (isPickup) {
      bloc.add(BookingPickupLocationSelected(
        location: result.location,
        address: result.address,
      ));
    } else {
      bloc.add(BookingDropLocationSelected(
        location: result.location,
        address: result.address,
      ));
    }
  }

  // ── Date & time picking ────────────────────────────────────────────────────

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final scheduled = DateTime(
      date.year, date.month, date.day, time.hour, time.minute,
    );
    context
        .read<BookingBloc>()
        .add(BookingDateTimeSelected(dateTime: scheduled));
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  void _submit(BookingInProgress state) {
    if (_notesController.text.trim().isNotEmpty) {
      context
          .read<BookingBloc>()
          .add(BookingNotesUpdated(notes: _notesController.text.trim()));
    }
    context.read<BookingBloc>().add(const BookingSubmitRequested());
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is BookingSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Booking request sent! Waiting for provider.'),
            backgroundColor: AppTheme.successColor,
          ));
          context.go(AppRoutes.seekerHome);
        } else if (state is BookingError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.errorColor,
          ));
        } else if (state is BookingInProgress) {
          _fitMapToLocations(state);
          // Auto-calculate price when both locations are ready
          if (state.isReadyForPriceCalculation && state.estimatedPrice == null) {
            context
                .read<BookingBloc>()
                .add(const BookingCalculatePriceRequested());
          }
        }
      },
      builder: (context, state) {
        final inProgress = state is BookingInProgress
            ? state
            : state is BookingCalculating
                ? state.currentState
                : state is BookingSubmitting
                    ? state.bookingData
                    : null;

        final isCalculating = state is BookingCalculating;
        final isSubmitting = state is BookingSubmitting;
        final isFixedOrigin =
            inProgress?.bookingMode == ServiceBookingMode.fixedOrigin;

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(inProgress),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildServiceSummaryCard(),
                      const SizedBox(height: 16),
                      _buildLocationSection(
                        inProgress,
                        isFixedOrigin: isFixedOrigin,
                      ),
                      const SizedBox(height: 16),
                      _buildDateTimeCard(inProgress),
                      const SizedBox(height: 16),
                      if (inProgress?.estimatedPrice != null || isCalculating)
                        _buildPriceCard(inProgress, isCalculating),
                      const SizedBox(height: 16),
                      _buildNotesCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildConfirmBar(
            inProgress,
            isSubmitting: isSubmitting,
            isCalculating: isCalculating,
          ),
        );
      },
    );
  }

  // ── Sliver App Bar with Map ────────────────────────────────────────────────

  Widget _buildSliverAppBar(BookingInProgress? state) {
    final pickupPt = state?.pickupLocation;
    final dropPt = state?.dropLocation;

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      title: Text(
        widget.service.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pickupPt ??
                    const LatLng(
                      AppConstants.defaultLatitude,
                      AppConstants.defaultLongitude,
                    ),
                initialZoom: 11,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
                onMapReady: () => setState(() => _mapReady = true),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapEndpoints.osmTileTemplate,
                  userAgentPackageName: 'com.haulistry.app',
                ),
                if (pickupPt != null || dropPt != null)
                  MarkerLayer(markers: [
                    if (pickupPt != null)
                      Marker(
                        point: pickupPt,
                        width: 36,
                        height: 36,
                        child: _MapPin(color: AppTheme.primaryColor),
                      ),
                    if (dropPt != null)
                      Marker(
                        point: dropPt,
                        width: 36,
                        height: 36,
                        child: _MapPin(color: AppTheme.secondaryColor),
                      ),
                  ]),
                if (pickupPt != null && dropPt != null)
                  PolylineLayer<Object>(polylines: [
                    Polyline(
                      points: [pickupPt, dropPt],
                      color: AppTheme.primaryColor.withOpacity(0.6),
                      strokeWidth: 2.5,
                    ),
                  ]),
              ],
            ),
            // Gradient fade at bottom for readability
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppTheme.backgroundColor,
                      AppTheme.backgroundColor.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Service Summary Card ───────────────────────────────────────────────────

  Widget _buildServiceSummaryCard() {
    final svc = widget.service;
    final cat = AppConstants.serviceCategories
        .firstWhere((c) => c.value == svc.category,
            orElse: () => const ServiceCategory(
                value: '', label: 'Service', emoji: '🚛'))
;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(cat.emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(svc.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                if (svc.providerName != null)
                  Text(svc.providerName!,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (svc.providerRating != null)
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFC107), size: 16),
                const SizedBox(width: 3),
                Text(svc.providerRating!.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ],
            ),
        ],
      ),
    );
  }

  // ── Location Section ───────────────────────────────────────────────────────

  Widget _buildLocationSection(
    BookingInProgress? state, {
    required bool isFixedOrigin,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Locations', Icons.location_on_rounded),
          const SizedBox(height: 14),
          if (isFixedOrigin) ...[
            // Provider's base location — read-only
            _buildBaseLocationTile(state),
            _buildVerticalConnector(),
            // Seeker's work site — user selects
            _buildLocationTile(
              icon: Icons.agriculture_rounded,
              iconColor: AppTheme.secondaryColor,
              label: 'Your Work / Field Site',
              address: state?.dropAddress,
              placeholder: 'Tap to pin your work location',
              onTap: () => _pickLocation(
                title: 'Work Site Location',
                subtitle: 'Where do you need the machine?',
                initialLocation: state?.dropLocation,
                isPickup: false,
                isWorkSite: true,
              ),
            ),
          ] else ...[
            // Transport: both locations from user
            _buildLocationTile(
              icon: Icons.trip_origin_rounded,
              iconColor: AppTheme.primaryColor,
              label: 'Pickup Location',
              address: state?.pickupAddress,
              placeholder: 'Where to pick up?',
              onTap: () => _pickLocation(
                title: 'Pickup Location',
                subtitle: 'Where should the vehicle go?',
                initialLocation: state?.pickupLocation,
                isPickup: true,
                isWorkSite: false,
              ),
            ),
            _buildVerticalConnector(),
            _buildLocationTile(
              icon: Icons.location_on_rounded,
              iconColor: AppTheme.secondaryColor,
              label: 'Drop-off Location',
              address: state?.dropAddress,
              placeholder: 'Where to deliver?',
              onTap: () => _pickLocation(
                title: 'Drop-off Location',
                subtitle: 'Where should materials be delivered?',
                initialLocation: state?.dropLocation,
                isPickup: false,
                isWorkSite: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBaseLocationTile(BookingInProgress? state) {
    final svc = widget.service;
    final address = state?.pickupAddress ?? svc.serviceBaseAddress;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.business_center_rounded,
                color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Provider Base Location',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                        letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(
                  address ?? 'Provider\'s registered base',
                  style: TextStyle(
                      fontSize: 13,
                      color: address != null
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('AUTO',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                    letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String? address,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final hasValue = address != null && address.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasValue
              ? AppTheme.cardColor
              : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? const Color(0xFFE5E7EB)
                : AppTheme.primaryColor.withOpacity(0.4),
            width: hasValue ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? address! : placeholder,
                    style: TextStyle(
                        fontSize: 13,
                        color: hasValue
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary.withOpacity(0.7)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              hasValue ? Icons.edit_location_alt_rounded : Icons.add_location_alt_rounded,
              color: iconColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalConnector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 19),
      child: Column(
        children: List.generate(
          4,
          (_) => Container(
            width: 2,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }

  // ── Date & Time Card ───────────────────────────────────────────────────────

  Widget _buildDateTimeCard(BookingInProgress? state) {
    final dt = state?.scheduledDateTime;
    final hasValue = dt != null;
    return GestureDetector(
      onTap: _pickDateTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(
          borderColor: hasValue
              ? null
              : AppTheme.primaryColor.withOpacity(0.35),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Scheduled Date & Time', null, compact: true),
                  const SizedBox(height: 4),
                  Text(
                    hasValue
                        ? DateFormat('EEE, d MMM y  •  h:mm a').format(dt)
                        : 'Tap to choose date and time',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                        color: hasValue
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  // ── Price Card ─────────────────────────────────────────────────────────────

  Widget _buildPriceCard(BookingInProgress? state, bool isCalculating) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.08),
            AppTheme.primaryColor.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Price Estimate', Icons.receipt_long_rounded),
          const SizedBox(height: 12),
          if (isCalculating)
            const Center(
              child: SizedBox(
                height: 36,
                width: 36,
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else ...[
            if (state?.distance != null)
              _priceRow(
                  Icons.straighten_rounded,
                  'Distance',
                  '${state!.distance!.toStringAsFixed(1)} km'),
            if (state?.estimatedPrice != null)
              _priceRow(
                Icons.payments_rounded,
                'Estimated Price',
                'Rs. ${state!.estimatedPrice!.toStringAsFixed(0)}',
                highlight: true,
              ),
            const SizedBox(height: 6),
            Text(
              'Final price may vary based on actual work done.',
              style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary.withOpacity(0.8)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(IconData icon, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: highlight
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
                fontSize: highlight ? 18 : 13,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight
                    ? AppTheme.primaryColor
                    : AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  // ── Notes Card ─────────────────────────────────────────────────────────────

  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Notes (optional)', Icons.notes_rounded),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Any special instructions, gate codes, road conditions…',
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary.withOpacity(0.7)),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppTheme.primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Confirm Bar ────────────────────────────────────────────────────────────

  Widget _buildConfirmBar(
    BookingInProgress? state, {
    required bool isSubmitting,
    required bool isCalculating,
  }) {
    final canSubmit = state?.isReadyForSubmission ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: (canSubmit && !isSubmitting && !isCalculating)
                ? () => _submit(state!)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              disabledBackgroundColor:
                  AppTheme.primaryColor.withOpacity(0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 20, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        _buttonLabel(state),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _buttonLabel(BookingInProgress? state) {
    if (state == null) return 'Complete the form above';
    if (!_hasLocations(state)) return 'Select locations to continue';
    if (state.scheduledDateTime == null) return 'Pick a date & time';
    if (state.estimatedPrice == null) return 'Calculating price…';
    return 'Confirm Booking Request';
  }

  bool _hasLocations(BookingInProgress state) {
    if (state.isFixedOrigin) return state.dropLocation != null;
    return state.pickupLocation != null && state.dropLocation != null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration({Color? borderColor}) => BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  Widget _sectionTitle(String title, IconData? icon, {bool compact = false}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 15 : 17, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 12 : 12.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ── Map Pin Widget ─────────────────────────────────────────────────────────────

class _MapPin extends StatelessWidget {
  final Color color;
  const _MapPin({required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.location_on_rounded, color: color, size: 36);
  }
}
