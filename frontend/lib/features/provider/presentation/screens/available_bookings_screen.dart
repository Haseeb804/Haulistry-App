import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/provider_bloc.dart';
import '../bloc/provider_event.dart';
import '../bloc/provider_state.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/domain/entities/vehicle_entity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';

/// Screen for providers to view available bookings and create fare offers
class AvailableBookingsScreen extends StatefulWidget {
  const AvailableBookingsScreen({super.key});

  @override
  State<AvailableBookingsScreen> createState() => _AvailableBookingsScreenState();
}

class _AvailableBookingsScreenState extends State<AvailableBookingsScreen> {
  String? _selectedServiceFilter;

  @override
  void initState() {
    super.initState();
    _loadAvailableBookings();
  }

  void _loadAvailableBookings() {
    context.read<ProviderBloc>().add(
          ProviderLoadAvailableBookingsRequested(
            serviceType: _selectedServiceFilter,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Modern SliverAppBar with gradient
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.secondaryColor,
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.filter_list, color: Colors.white, size: 20),
                ),
                onPressed: _showFilterDialog,
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                ),
                onPressed: _loadAvailableBookings,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.secondaryGradient,
                ),
                child: Stack(
                  children: [
                    // Pattern decoration
                    Positioned.fill(
                      child: CustomPaint(
                        painter: AvailablePatternPainter(),
                      ),
                    ),
                    // Content
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.local_shipping, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Available Bookings',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_selectedServiceFilter != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Filter: $_selectedServiceFilter',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
          ),
          
          // Content
          BlocConsumer<ProviderBloc, ProviderState>(
            listener: (context, state) {
              if (state is ProviderOfferCreatedSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text('Offer sent: Rs. ${state.offer.offeredPrice.toStringAsFixed(0)}'),
                      ],
                    ),
                    backgroundColor: AppTheme.secondaryColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              } else if (state is ProviderError) {
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
              if (state is ProviderLoading) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.secondaryColor),
                        SizedBox(height: 16),
                        Text('Loading available bookings...'),
                      ],
                    ),
                  ),
                );
              }

              if (state is ProviderLoaded) {
                if (state.availableBookings.isEmpty) {
                  return SliverFillRemaining(child: _buildEmptyState());
                }
                return _buildBookingsList(state);
              }

              return SliverFillRemaining(child: _buildEmptyState());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: EmptyStateWidget(
          icon: Icons.search_off,
          title: 'No bookings available',
          subtitle: 'Check back later for new booking requests in your area.',
          buttonText: 'Refresh',
          onButtonPressed: _loadAvailableBookings,
        ),
      ),
    );
  }

  SliverPadding _buildBookingsList(ProviderLoaded state) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildBookingCard(
              state.availableBookings[index],
              state.vehicles,
            );
          },
          childCount: state.availableBookings.length,
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingEntity booking, List<VehicleEntity> vehicles) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.secondaryColor.withOpacity(0.1),
                  AppTheme.secondaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.category, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        booking.serviceType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (booking.isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'URGENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Locations
                _buildLocationRow(
                  icon: Icons.radio_button_checked,
                  color: AppTheme.secondaryColor,
                  label: 'Pickup',
                  address: booking.pickupAddress,
                ),
                Container(
                  margin: const EdgeInsets.only(left: 11),
                  height: 24,
                  width: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                _buildLocationRow(
                  icon: Icons.location_on,
                  color: AppTheme.primaryColor,
                  label: 'Drop',
                  address: booking.dropAddress,
                ),
                const SizedBox(height: 16),
                
                // Details row
                Row(
                  children: [
                    _buildDetailChip(
                      icon: Icons.straighten,
                      label: '${booking.distanceInKm.toStringAsFixed(1)} km',
                      gradient: AppTheme.accentGradient,
                    ),
                    const SizedBox(width: 12),
                    _buildDetailChip(
                      icon: Icons.schedule,
                      label: _formatSchedule(booking.scheduledDateTime),
                      gradient: AppTheme.primaryGradient,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Estimated price
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.1),
                        AppTheme.primaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
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
                          Text(
                            'Estimated Price',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Rs. ${booking.estimatedPrice.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Action button
                GradientButton(
                  text: 'Make an Offer',
                  onPressed: () => _showCreateOfferDialog(booking, vehicles),
                  icon: Icons.local_offer,
                  gradient: AppTheme.secondaryGradient,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient.colors.first.withOpacity(0.1),
            gradient.colors.last.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: gradient.colors.first),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: gradient.colors.first,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSchedule(DateTime dateTime) {
    final now = DateTime.now();
    final diff = dateTime.difference(now);

    if (diff.isNegative) {
      return 'ASAP';
    } else if (diff.inMinutes < 60) {
      return 'In ${diff.inMinutes} mins';
    } else if (diff.inHours < 24) {
      return 'In ${diff.inHours} hours';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.filter_list, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Filter by Service',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildFilterChip(null, 'All'),
                _buildFilterChip('Dumper', 'Dumper'),
                _buildFilterChip('Crane', 'Crane'),
                _buildFilterChip('Harvester', 'Harvester'),
                _buildFilterChip('Excavator', 'Excavator'),
                _buildFilterChip('Tractor', 'Tractor'),
              ],
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Apply Filter',
              onPressed: () {
                Navigator.pop(context);
                _loadAvailableBookings();
              },
              gradient: AppTheme.secondaryGradient,
              icon: Icons.check,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String? value, String label) {
    final isSelected = _selectedServiceFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedServiceFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.secondaryGradient : null,
          color: isSelected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showCreateOfferDialog(BookingEntity booking, List<VehicleEntity> vehicles) {
    final priceController = TextEditingController(
      text: booking.estimatedPrice.toStringAsFixed(0),
    );
    final messageController = TextEditingController();
    final arrivalController = TextEditingController(text: '15');
    VehicleEntity? selectedVehicle;

    // Filter available vehicles
    final availableVehicles = vehicles.where((v) => v.isAvailable).toList();

    if (availableVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You have no available vehicles. Please add or enable a vehicle first.'),
          backgroundColor: Colors.orange.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    selectedVehicle = availableVehicles.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.local_offer, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Fare Offer',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Estimated: Rs. ${booking.estimatedPrice.toStringAsFixed(0)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Vehicle selector
              _buildModernDropdown(
                value: selectedVehicle,
                label: 'Select Vehicle',
                icon: Icons.local_shipping,
                items: availableVehicles,
                onChanged: (value) {
                  setModalState(() {
                    selectedVehicle = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Price input
              _buildModernTextField(
                controller: priceController,
                label: 'Your Offer Price',
                icon: Icons.payments,
                prefixText: 'Rs. ',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              
              // Arrival time
              _buildModernTextField(
                controller: arrivalController,
                label: 'Estimated Arrival',
                icon: Icons.access_time,
                suffixText: 'minutes',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              
              // Message
              _buildModernTextField(
                controller: messageController,
                label: 'Message (optional)',
                icon: Icons.message,
                hintText: 'Add a note for the customer...',
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              
              GradientButton(
                text: 'Send Offer',
                onPressed: () {
                  final price = double.tryParse(priceController.text);
                  final arrival = int.tryParse(arrivalController.text);

                  if (price == null || price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please enter a valid price'),
                        backgroundColor: Colors.red.shade400,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    return;
                  }

                  if (selectedVehicle == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please select a vehicle'),
                        backgroundColor: Colors.red.shade400,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  context.read<ProviderBloc>().add(
                        ProviderCreateFareOfferRequested(
                          bookingId: booking.id,
                          vehicleId: selectedVehicle!.id,
                          offeredPrice: price,
                          message: messageController.text.isEmpty
                              ? null
                              : messageController.text,
                          estimatedArrivalMinutes: arrival,
                        ),
                      );
                },
                icon: Icons.send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    String? prefixText,
    String? suffixText,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixText: prefixText,
          suffixText: suffixText,
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildModernDropdown({
    required VehicleEntity? value,
    required String label,
    required IconData icon,
    required List<VehicleEntity> items,
    required ValueChanged<VehicleEntity?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<VehicleEntity>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.secondaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items.map((vehicle) {
          return DropdownMenuItem(
            value: vehicle,
            child: Text('${vehicle.vehicleType} - ${vehicle.vehicleNumber}'),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// Custom pattern painter for available bookings header
class AvailablePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Draw decorative circles
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.2), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.7), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.1), 30, paint);

    // Draw truck path
    final pathPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.3,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.7,
      size.width,
      size.height * 0.4,
    );
    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
