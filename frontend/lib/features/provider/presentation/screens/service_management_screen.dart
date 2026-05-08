import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import '../../../../core/domain/entities/service_entity.dart';
import '../../../../core/domain/entities/vehicle_entity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../bloc/provider_bloc.dart';
import '../bloc/provider_event.dart';
import '../bloc/provider_state.dart';
import '../widgets/dynamic_service_fields.dart';

class ServiceManagementScreen extends StatefulWidget {
  const ServiceManagementScreen({super.key});

  @override
  State<ServiceManagementScreen> createState() => _ServiceManagementScreenState();
}

class _ServiceManagementScreenState extends State<ServiceManagementScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProviderBloc>().add(const ProviderLoadServicesRequested());
    context.read<ProviderBloc>().add(const ProviderLoadVehiclesRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: BlocConsumer<ProviderBloc, ProviderState>(
        listener: (context, state) {
          if (state is ProviderServiceActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(state.message),
                  ],
                ),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          } else if (state is ProviderError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          List<ServiceEntity> services = [];
          List<VehicleEntity> vehicles = [];
          bool isLoading = state is ProviderLoading || state is ProviderServiceActionInProgress;

          if (state is ProviderLoaded) {
            services = state.services;
            vehicles = state.vehicles;
          } else if (state is ProviderServicesLoaded) {
            services = state.services;
            // Vehicles not available in this state, try to get from bloc
          }

          return CustomScrollView(
            slivers: [
              // Modern App Bar with gradient
              SliverAppBar(
                expandedHeight: 140,
                floating: true,
                pinned: true,
                backgroundColor: AppTheme.primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.home_repair_service_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'My Services',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${services.length} active services',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chevron_left_rounded, 
                        color: Colors.white, size: 18),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: const [],
              ),

              // Content
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryColor),
                        SizedBox(height: 16),
                        Text('Loading services...'),
                      ],
                    ),
                  ),
                )
              else if (services.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context, vehicles),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildServiceCard(context, services[index], vehicles),
                      childCount: services.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: BlocBuilder<ProviderBloc, ProviderState>(
        builder: (context, state) {
          List<VehicleEntity> vehicles = [];
          if (state is ProviderLoaded) {
            vehicles = state.vehicles;
          }
          
          return FloatingActionButton.extended(
            onPressed: () => _showAddServiceDialog(context, vehicles),
            backgroundColor: AppTheme.primaryColor,
            elevation: 4,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Service'),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, List<VehicleEntity> vehicles) {
    return EmptyStateWidget(
      icon: Icons.agriculture_rounded,
      title: 'No Services Yet',
      subtitle: 'Add your agriculture or construction services\nto start receiving bookings',
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    ServiceEntity service,
    List<VehicleEntity> vehicles,
  ) {
    final vehicle = vehicles.firstWhere(
      (v) => v.id == service.vehicleId,
      orElse: () => VehicleEntity(
        id: '',
        providerId: '',
        vehicleType: 'Unknown',
        vehicleNumber: '',
        vehicleModel: '',
        vehicleYear: '',
        isAvailable: false,
        capacity: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Category Gradient
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: _getCategoryGradient(service.category),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Stack(
              children: [
                // Pattern overlay
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.1,
                    child: CustomPaint(
                      painter: PatternPainter(),
                    ),
                  ),
                ),
                // Icon and Category
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getCategoryIcon(service.category),
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              service.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formatCategory(service.category),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: service.isActive
                              ? AppTheme.successColor
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              service.isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.pause_circle_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              service.isActive ? 'Active' : 'Paused',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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

          // Content Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                if (service.description != null && service.description!.isNotEmpty) ...[
                  Text(
                    service.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                ],

                // Vehicle Info Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildVehicleImage(vehicle),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (vehicle.vehicleModel?.isNotEmpty ?? false)
                                  ? vehicle.vehicleModel!
                                  : vehicle.vehicleType,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              vehicle.vehicleNumber,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${vehicle.capacity?.toStringAsFixed(0) ?? '0'} Ton',
                          style: const TextStyle(
                            color: AppTheme.secondaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Pricing Row
                Row(
                  children: [
                    Expanded(child: _buildPriceCard(context, 'Base', service.basePrice, Icons.attach_money_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildPriceCard(context, 'Per Km', service.pricePerKm, Icons.route_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildPriceCard(context, 'Per Hour', service.pricePerHour, Icons.schedule_rounded)),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditServiceDialog(context, service, vehicles),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDeleteService(context, service),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: BorderSide(
                            color: AppTheme.errorColor.withOpacity(0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
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

  Widget _buildPriceCard(BuildContext context, String label, double price, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(height: 6),
          Text(
            'Rs ${price.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  LinearGradient _getCategoryGradient(String category) {
    switch (category.toLowerCase()) {
      case 'sand_trolley':
        return const LinearGradient(
          colors: [Color(0xFFFF9A56), Color(0xFFFFB347)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'bricks_trolley':
        return const LinearGradient(
          colors: [Color(0xFFE74C3C), Color(0xFFF39C12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'harvester':
        return const LinearGradient(
          colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'crane':
        return const LinearGradient(
          colors: [Color(0xFF3498DB), Color(0xFF5DADE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'tractor':
        return const LinearGradient(
          colors: [Color(0xFF16A085), Color(0xFF1ABC9C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'loader':
        return const LinearGradient(
          colors: [Color(0xFF8E44AD), Color(0xFF9B59B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'excavator':
        return const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'concrete_mixer':
        return const LinearGradient(
          colors: [Color(0xFF7F8C8D), Color(0xFF95A5A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'water_tanker':
        return const LinearGradient(
          colors: [Color(0xFF0984E3), Color(0xFF74B9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return AppTheme.primaryGradient;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'sand_trolley':
        return Icons.landscape_rounded;
      case 'bricks_trolley':
        return Icons.grid_view_rounded;
      case 'harvester':
        return Icons.agriculture_rounded;
      case 'crane':
        return Icons.precision_manufacturing_rounded;
      case 'tractor':
        return Icons.agriculture;
      case 'loader':
        return Icons.front_loader;
      case 'dumper':
        return Icons.local_shipping_rounded;
      case 'excavator':
        return Icons.construction_rounded;
      case 'concrete_mixer':
        return Icons.blender_rounded;
      case 'water_tanker':
        return Icons.water_drop_rounded;
      default:
        return Icons.handyman_rounded;
    }
  }

  String _formatCategory(String category) {
    return category.replaceAll('_', ' ').toUpperCase();
  }

  Widget _buildVehicleImage(VehicleEntity vehicle) {
    final hasImage = vehicle.vehicleImageBase64 != null && 
                     vehicle.vehicleImageBase64!.isNotEmpty;
    
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.memory(
                base64Decode(vehicle.vehicleImageBase64!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildVehicleIcon(vehicle.vehicleType);
                },
              )
            : _buildVehicleIcon(vehicle.vehicleType),
      ),
    );
  }

  Widget _buildVehicleIcon(String vehicleType) {
    return Center(
      child: Icon(
        _getVehicleIcon(vehicleType),
        color: AppTheme.primaryColor,
        size: 24,
      ),
    );
  }

  IconData _getVehicleIcon(String vehicleType) {
    final type = vehicleType.toLowerCase();
    if (type.contains('trolley') || type.contains('sand') || type.contains('brick')) {
      return Icons.local_shipping_rounded;
    }
    if (type.contains('harvester')) return Icons.agriculture_rounded;
    if (type.contains('tractor')) return Icons.agriculture;
    if (type.contains('crane')) return Icons.precision_manufacturing_rounded;
    if (type.contains('excavator')) return Icons.construction_rounded;
    if (type.contains('loader')) return Icons.front_loader;
    if (type.contains('dumper')) return Icons.local_shipping_rounded;
    if (type.contains('mixer') || type.contains('concrete')) return Icons.blender_rounded;
    if (type.contains('tanker')) return Icons.water_drop_rounded;
    return Icons.local_shipping_rounded;
  }

  void _showAddServiceDialog(BuildContext context, List<VehicleEntity> vehicles) {
    _showServiceDialog(context, null, vehicles);
  }

  void _showEditServiceDialog(BuildContext context, ServiceEntity service, List<VehicleEntity> vehicles) {
    _showServiceDialog(context, service, vehicles);
  }

  void _showServiceDialog(BuildContext context, ServiceEntity? existingService, List<VehicleEntity> vehicles) {
    final isEditing = existingService != null;
    final nameController = TextEditingController(text: existingService?.name ?? '');
    final descriptionController = TextEditingController(text: existingService?.description ?? '');
    final basePriceController = TextEditingController(
      text: existingService != null ? existingService.basePrice.toString() : '500',
    );
    final pricePerKmController = TextEditingController(
      text: existingService != null ? existingService.pricePerKm.toString() : '0',
    );
    final pricePerHourController = TextEditingController(
      text: existingService != null ? existingService.pricePerHour.toString() : '0',
    );

    String selectedCategory = existingService?.category ?? 'sand_trolley';
    String? selectedVehicleId = existingService?.vehicleId;
    if (selectedVehicleId == null && vehicles.isNotEmpty) {
      selectedVehicleId = vehicles.first.id;
    }

    // Parse existing extraFields JSON into a map for pre-population.
    Map<String, dynamic> extraFieldValues = {};
    if (existingService?.extraFields != null) {
      try {
        extraFieldValues = Map<String, dynamic>.from(
          jsonDecode(existingService!.extraFields!),
        );
      } catch (_) {}
    }

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.92,
                minChildSize: 0.5,
                maxChildSize: 0.97,
                expand: false,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                        left: 24,
                        right: 24,
                        top: 12,
                      ),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Handle
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isEditing ? Icons.edit_rounded : Icons.add_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEditing ? 'Edit Service' : 'Add New Service',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      Text(
                                        isEditing
                                            ? 'Update your service details'
                                            : 'Create a new service offering',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 20),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // Vehicle Selection
                            if (vehicles.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.warning_rounded, color: AppTheme.errorColor),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No vehicles found. Please add a vehicle first.',
                                        style: TextStyle(color: AppTheme.errorColor),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                value: selectedVehicleId,
                                decoration: InputDecoration(
                                  labelText: 'Select Vehicle',
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(12),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.local_shipping_rounded,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                items: vehicles.map((v) {
                                  return DropdownMenuItem(
                                    value: v.id,
                                    child: Text('${v.vehicleType} - ${v.vehicleNumber}'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setDialogState(() => selectedVehicleId = value);
                                },
                                validator: (value) => (value == null || value.isEmpty)
                                    ? 'Please select a vehicle'
                                    : null,
                              ),
                            const SizedBox(height: 20),

                            // Service Name
                            TextFormField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'Service Name',
                                hintText: 'e.g., Sand Transport, Harvesting Service',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(12),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.label_rounded,
                                    color: AppTheme.secondaryColor,
                                    size: 18,
                                  ),
                                ),
                              ),
                              validator: (value) => (value == null || value.isEmpty)
                                  ? 'Please enter service name'
                                  : null,
                            ),
                            const SizedBox(height: 20),

                            // Category — changing this rebuilds the dynamic fields below
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: InputDecoration(
                                labelText: 'Service Category',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(12),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.category_rounded,
                                    color: AppTheme.accentColor,
                                    size: 18,
                                  ),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'sand_trolley', child: Text('Sand Trolley')),
                                DropdownMenuItem(value: 'bricks_trolley', child: Text('Bricks Trolley')),
                                DropdownMenuItem(value: 'harvester', child: Text('Harvester')),
                                DropdownMenuItem(value: 'crane', child: Text('Crane')),
                                DropdownMenuItem(value: 'tractor', child: Text('Tractor')),
                                DropdownMenuItem(value: 'loader', child: Text('Loader')),
                                DropdownMenuItem(value: 'dumper', child: Text('Dumper')),
                                DropdownMenuItem(value: 'excavator', child: Text('Excavator')),
                                DropdownMenuItem(value: 'concrete_mixer', child: Text('Concrete Mixer')),
                                DropdownMenuItem(value: 'water_tanker', child: Text('Water Tanker')),
                                DropdownMenuItem(value: 'other', child: Text('Other')),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedCategory = value ?? 'sand_trolley';
                                  // Reset extra fields when category changes.
                                  extraFieldValues = {};
                                });
                              },
                            ),
                            const SizedBox(height: 20),

                            // Description
                            TextFormField(
                              controller: descriptionController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText: 'Describe your service, capacity, coverage area...',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Dynamic service-specific fields ──────────────────
                            DynamicServiceFields(
                              key: ValueKey(selectedCategory),
                              category: selectedCategory,
                              initialValues: extraFieldValues,
                              onChanged: (values) {
                                extraFieldValues = values;
                              },
                            ),

                            // Pricing Section
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.secondaryGradient,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.payments_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Base Pricing',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Used for fare estimation. Set 0 if not applicable.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: basePriceController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Base Price (Rs)',
                                      prefixIcon: Icon(Icons.attach_money_rounded),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Required';
                                      if (double.tryParse(value) == null) return 'Invalid amount';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: pricePerKmController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Per Km (Rs)',
                                            prefixIcon: Icon(Icons.route_rounded),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) return 'Required';
                                            if (double.tryParse(value) == null) return 'Invalid';
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: pricePerHourController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Per Hour (Rs)',
                                            prefixIcon: Icon(Icons.schedule_rounded),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) return 'Required';
                                            if (double.tryParse(value) == null) return 'Invalid';
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Submit Button
                            GradientButton(
                              text: isEditing ? 'Update Service' : 'Add Service',
                              icon: isEditing ? Icons.check_rounded : Icons.add_rounded,
                              onPressed: vehicles.isEmpty
                                  ? null
                                  : () {
                                      if (!formKey.currentState!.validate()) return;
                                      final encodedExtra = extraFieldValues.isNotEmpty
                                          ? jsonEncode(extraFieldValues)
                                          : null;

                                      Navigator.pop(context);

                                      if (isEditing) {
                                        context.read<ProviderBloc>().add(
                                              ProviderUpdateServiceRequested(
                                                serviceId: existingService.id,
                                                updates: {
                                                  'name': nameController.text.trim(),
                                                  'description': descriptionController.text.trim(),
                                                  'basePrice': double.parse(basePriceController.text),
                                                  'pricePerKm': double.parse(pricePerKmController.text),
                                                  'pricePerHour': double.parse(pricePerHourController.text),
                                                  'category': selectedCategory,
                                                  if (encodedExtra != null) 'extraFields': encodedExtra,
                                                },
                                              ),
                                            );
                                      } else {
                                        context.read<ProviderBloc>().add(
                                              ProviderAddServiceRequested(
                                                vehicleId: selectedVehicleId!,
                                                name: nameController.text.trim(),
                                                description: descriptionController.text.trim(),
                                                basePrice: double.parse(basePriceController.text),
                                                pricePerKm: double.parse(pricePerKmController.text),
                                                pricePerHour: double.parse(pricePerHourController.text),
                                                category: selectedCategory,
                                                extraFields: encodedExtra,
                                              ),
                                            );
                                      }
                                    },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteService(BuildContext context, ServiceEntity service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_rounded, color: AppTheme.errorColor),
            ),
            const SizedBox(width: 12),
            const Text('Delete Service'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${service.name}"?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ProviderBloc>().add(
                    ProviderDeleteServiceRequested(serviceId: service.id),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for pattern overlay
class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    const spacing = 30.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
