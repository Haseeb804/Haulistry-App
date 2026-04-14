import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../services/domain/entities/service_entity.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import 'location_picker_screen.dart';

class CreateBookingScreen extends StatefulWidget {
  final ServiceEntity? service;
  final String? serviceType;

  const CreateBookingScreen({
    super.key,
    required this.service,
  }) : serviceType = null;
  
  /// Legacy constructor for backward compatibility
  const CreateBookingScreen.fromServiceType({
    super.key,
    required this.serviceType,
  }) : service = null;

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize booking with service
    final serviceType = widget.service?.category ?? widget.serviceType ?? '';
    context.read<BookingBloc>().add(
          BookingServiceSelected(
            serviceType: serviceType,
            service: widget.service,
          ),
        );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectPickupLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(
          title: 'Select Pickup Location',
        ),
      ),
    );

    if (result != null && mounted) {
      context.read<BookingBloc>().add(
            BookingPickupLocationSelected(
              location: result['location'],
              address: result['address'],
            ),
          );
    }
  }

  Future<void> _selectDropLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(
          title: 'Select Drop Location',
        ),
      ),
    );

    if (result != null && mounted) {
      context.read<BookingBloc>().add(
            BookingDropLocationSelected(
              location: result['location'],
              address: result['address'],
            ),
          );
    }
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppTheme.primaryColor,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null && mounted) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        context.read<BookingBloc>().add(
              BookingDateTimeSelected(dateTime: dateTime),
            );
      }
    }
  }

  void _calculatePrice() {
    context.read<BookingBloc>().add(const BookingCalculatePriceRequested());
  }

  void _proceedToConfirmation() {
    final state = context.read<BookingBloc>().state;
    if (state is BookingInProgress && state.isReadyForSubmission) {
      context.push('/booking/confirm');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: BlocConsumer<BookingBloc, BookingState>(
        listener: (context, state) {
          if (state is BookingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade400,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is BookingCalculating) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Calculating price...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final bookingState = state is BookingInProgress
              ? state
              : state is BookingError && state.currentState != null
                  ? state.currentState!
                  : const BookingInProgress(serviceType: '');

          return Column(
            children: [
              // Map Header with gradient overlay
              _buildMapHeader(bookingState),
              
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Info Card - Modern Style with Provider Details
                      _buildServiceInfoCard(),
                      const SizedBox(height: 24),

                      // Pickup Location Section
                      _buildSectionHeader('Pickup Location', Icons.trip_origin, AppTheme.secondaryGradient),
                      const SizedBox(height: 12),
                      _buildLocationCard(
                        icon: Icons.my_location,
                        label: 'Pickup Point',
                        address: bookingState.pickupAddress,
                        onTap: _selectPickupLocation,
                        gradient: AppTheme.secondaryGradient,
                      ),
                      const SizedBox(height: 20),

                      // Drop Location Section
                      _buildSectionHeader('Drop Location', Icons.location_on, AppTheme.primaryGradient),
                      const SizedBox(height: 12),
                      _buildLocationCard(
                        icon: Icons.location_on,
                        label: 'Drop Point',
                        address: bookingState.dropAddress,
                        onTap: _selectDropLocation,
                        gradient: AppTheme.primaryGradient,
                      ),
                      const SizedBox(height: 24),

                      // Date & Time Section
                      _buildSectionHeader('Schedule', Icons.schedule, AppTheme.accentGradient),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppTheme.accentGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                          ),
                          title: Text(
                            bookingState.scheduledDateTime != null
                                ? DateFormat('MMM dd, yyyy - hh:mm a')
                                    .format(bookingState.scheduledDateTime!)
                                : 'Select Date & Time',
                            style: TextStyle(
                              fontWeight: bookingState.scheduledDateTime != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: bookingState.scheduledDateTime != null
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.accentColor),
                          ),
                          onTap: _selectDateTime,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Calculate Price Button
                      if (bookingState.isReadyForPriceCalculation &&
                          bookingState.estimatedPrice == null)
                        GradientButton(
                          text: 'Calculate Price',
                          onPressed: _calculatePrice,
                          icon: Icons.calculate,
                          gradient: AppTheme.accentGradient,
                        ),

                      // Distance & Price Display - Modern Style
                      if (bookingState.distance != null &&
                          bookingState.estimatedPrice != null) ...[
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.1),
                                AppTheme.secondaryColor.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: AppTheme.secondaryGradient,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.straighten, color: Colors.white, size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Distance', style: TextStyle(fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    Text(
                                      '${bookingState.distance!.toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        AppTheme.primaryColor.withOpacity(0.3),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: AppTheme.primaryGradient,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.payments, color: Colors.white, size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Estimated Price', style: TextStyle(fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                      child: Text(
                                        'Rs. ${bookingState.estimatedPrice!.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Notes Section
                      _buildSectionHeader('Additional Notes', Icons.note_alt, AppTheme.accentGradient),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Any special instructions...',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          onChanged: (value) {
                            context.read<BookingBloc>().add(
                                  BookingNotesUpdated(notes: value),
                                );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Continue Button
                      GradientButton(
                        text: 'Continue to Confirmation',
                        onPressed: bookingState.isReadyForSubmission
                            ? _proceedToConfirmation
                            : null,
                        icon: Icons.arrow_forward,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, LinearGradient gradient) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMapHeader(BookingInProgress bookingState) {
    const defaultLocation = LatLng(31.5204, 74.3587);
    
    List<Marker> markers = [];
    List<Polyline> polylines = [];
    LatLng cameraPosition = defaultLocation;

    // Add pickup marker with gradient style
    if (bookingState.pickupLocation != null) {
      markers.add(
        Marker(
          point: bookingState.pickupLocation!,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.secondaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.trip_origin, color: Colors.white, size: 20),
          ),
        ),
      );
      cameraPosition = bookingState.pickupLocation!;
    }

    // Add drop marker with gradient style
    if (bookingState.dropLocation != null) {
      markers.add(
        Marker(
          point: bookingState.dropLocation!,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 20),
          ),
        ),
      );
      
      // Draw gradient-colored line between pickup and drop
      if (bookingState.pickupLocation != null) {
        polylines.add(
          Polyline(
            points: [bookingState.pickupLocation!, bookingState.dropLocation!],
            color: AppTheme.accentColor,
            strokeWidth: 4,
          ),
        );
      }
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Map
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: cameraPosition,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: MapEndpoints.osmTileTemplate,
                  userAgentPackageName: 'com.haulistry.app',
                ),
                if (polylines.isNotEmpty)
                  PolylineLayer(polylines: polylines),
                if (markers.isNotEmpty)
                  MarkerLayer(markers: markers),
              ],
            ),
          ),
          // Gradient overlay at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.9),
                    AppTheme.primaryColor.withOpacity(0.0),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
            ),
          ),
          // Back button and title
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.local_shipping, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Create Booking',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required IconData icon,
    required String label,
    String? address,
    required VoidCallback onTap,
    required LinearGradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address ?? 'Tap to select',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: address != null ? FontWeight.w600 : FontWeight.normal,
                          color: address != null ? Colors.black87 : Colors.grey.shade500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: gradient.colors.first.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_forward_ios, size: 14, color: gradient.colors.first),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceInfoCard() {
    final service = widget.service;
    final serviceType = service?.category ?? widget.serviceType ?? 'General';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Header with Image
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Stack(
              children: [
                // Background pattern
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ServicePatternPainter(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                // Vehicle image or icon
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Vehicle image
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: service?.vehicleImageBase64 != null &&
                                  service!.vehicleImageBase64!.isNotEmpty
                              ? Image.memory(
                                  base64Decode(service.vehicleImageBase64!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.local_shipping_rounded,
                                    size: 32,
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : const Icon(
                                  Icons.local_shipping_rounded,
                                  size: 32,
                                  color: AppTheme.primaryColor,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Service info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              service?.name ?? serviceType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (service?.vehicleType != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${service!.vehicleType} • ${service.vehicleNumber ?? ''}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Rating badge
                      if (service?.providerRating != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                service!.providerRating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Provider and Pricing Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Provider info row
                if (service?.providerName != null) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: service?.providerImageUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  service!.providerImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 20,
                                color: AppTheme.primaryColor,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Provider',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              service!.providerName!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                ],
                // Pricing breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPriceItem(
                      'Base Price',
                      'Rs. ${service?.basePrice.toStringAsFixed(0) ?? AppConstants.baseRates[serviceType]?.toStringAsFixed(0) ?? '100'}',
                      Icons.monetization_on_rounded,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade200,
                    ),
                    _buildPriceItem(
                      'Per Km',
                      'Rs. ${service?.pricePerKm.toStringAsFixed(0) ?? '10'}',
                      Icons.straighten_rounded,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade200,
                    ),
                    _buildPriceItem(
                      'Per Hour',
                      'Rs. ${service?.pricePerHour.toStringAsFixed(0) ?? '50'}',
                      Icons.access_time_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// Pattern painter for service card background
class _ServicePatternPainter extends CustomPainter {
  final Color color;

  _ServicePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
