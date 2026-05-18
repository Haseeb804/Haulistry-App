import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../bloc/provider_bloc.dart';
import '../bloc/provider_event.dart';
import '../bloc/provider_state.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() =>
      _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  // Cache the last ProviderLoaded state so the builder never shows a blank
  // screen during ProviderVehicleActionInProgress / ProviderVehicleActionSuccess
  // transitions — those intermediate states carry no data of their own.
  ProviderLoaded? _lastLoaded;

  @override
  void initState() {
    super.initState();
    // Seed cache immediately — ensures data is shown on first frame if already loaded.
    final current = context.read<ProviderBloc>().state;
    if (current is ProviderLoaded) {
      _lastLoaded = current;
    }
    // Always refresh in background; if _lastLoaded is non-null, no spinner is shown.
    context.read<ProviderBloc>().add(const ProviderLoadVehiclesRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: BlocConsumer<ProviderBloc, ProviderState>(
        listener: (context, state) {
          // Keep cache in sync whenever we get a fresh data state.
          if (state is ProviderLoaded) {
            _lastLoaded = state;
          }
          if (state is ProviderVehicleActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        },
        builder: (context, state) {
          // During vehicle CRUD actions, fall back to the last known loaded
          // state instead of a blank/loading screen.
          final effectiveState = (state is ProviderVehicleActionInProgress ||
                  state is ProviderVehicleActionSuccess)
              ? (_lastLoaded ?? state)
              : state;

          // Update cache immediately when the real state is ProviderLoaded.
          if (effectiveState is ProviderLoaded) {
            _lastLoaded = effectiveState;
          }

          // Only show full-screen spinner on initial dashboard load.
          if (effectiveState is ProviderLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading vehicles...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          if (effectiveState is ProviderInitial) {
            // Trigger loading when screen first shows
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<ProviderBloc>().add(const ProviderLoadVehiclesRequested());
            });
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (effectiveState is ProviderError) {
            return Center(
              child: EmptyStateWidget(
                icon: Icons.error_outline_rounded,
                title: 'Something went wrong',
                subtitle: effectiveState.message,
                buttonText: 'Retry',
                onButtonPressed: () {
                  context.read<ProviderBloc>().add(const ProviderLoadVehiclesRequested());
                },
              ),
            );
          }

          if (effectiveState is ProviderLoaded) {
            final loadedState = effectiveState;
            final isActionInProgress = state is ProviderVehicleActionInProgress;
            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    // Modern App Bar
                    SliverAppBar(
                      expandedHeight: 180,
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: const BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(32),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Pattern background
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: VehiclePatternPainter(
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                ),
                              ),
                              SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'My Vehicles',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Manage your fleet of ${loadedState.vehicles.length} vehicles',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
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
                    ),

                    // Stats Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.local_shipping_rounded,
                                value: loadedState.vehicles.length.toString(),
                                label: 'Total Vehicles',
                                gradient: AppTheme.primaryGradient,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.check_circle_rounded,
                                value: loadedState.activeVehicles.toString(),
                                label: 'Available',
                                gradient: AppTheme.secondaryGradient,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Vehicles List
                    if (loadedState.vehicles.isEmpty)
                      SliverFillRemaining(
                        child: _buildEmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final vehicle = loadedState.vehicles[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildVehicleCard(context, vehicle),
                              );
                            },
                            childCount: loadedState.vehicles.length,
                          ),
                        ),
                      ),

                    // Bottom padding
                    const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                  ],
                ),
                // Subtle action-in-progress overlay (non-blocking)
                if (isActionInProgress)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      color: AppTheme.primaryColor,
                      minHeight: 3,
                    ),
                  ),
              ],
            );
          }

          // Fallback — should not normally be reached.
          return Center(
            child: EmptyStateWidget(
              icon: Icons.refresh_rounded,
              title: 'Loading...',
              buttonText: 'Refresh',
              onButtonPressed: () {
                context.read<ProviderBloc>().add(const ProviderLoadVehiclesRequested());
              },
            ),
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddVehicleDialog(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Add Vehicle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, vehicle) {
    final vehicleEmoji = _getVehicleEmoji(vehicle.vehicleType);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  vehicle.isAvailable 
                      ? AppTheme.successColor.withOpacity(0.1)
                      : Colors.grey.shade200,
                  Colors.white,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                _buildVehicleImage(vehicle, vehicleEmoji),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _vehicleTypeLabel(vehicle.vehicleType),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (vehicle.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.successColor.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded, size: 12, color: AppTheme.successColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.successColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          vehicle.vehicleNumber,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch.adaptive(
                      value: vehicle.isAvailable,
                      activeColor: AppTheme.successColor,
                      onChanged: (value) {
                        context.read<ProviderBloc>().add(
                          ProviderToggleVehicleAvailability(
                            vehicleId: vehicle.id,
                            isAvailable: value,
                          ),
                        );
                      },
                    ),
                    Text(
                      vehicle.isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        fontSize: 10,
                        color: vehicle.isAvailable
                            ? AppTheme.successColor
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Auto-verified info banner
                if (vehicle.addedAfterVerification) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0984E3).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0984E3).withOpacity(0.25)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF0984E3)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Auto-verified · Visible to admin for review',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0984E3),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _buildVehicleDetail(
                        icon: Icons.directions_car_rounded,
                        label: 'Model',
                        value: vehicle.vehicleModel ?? 'N/A',
                        gradient: AppTheme.primaryGradient,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildVehicleDetail(
                        icon: Icons.calendar_today_rounded,
                        label: 'Year',
                        value: vehicle.vehicleYear ?? 'N/A',
                        gradient: AppTheme.accentGradient,
                      ),
                    ),
                  ],
                ),
                if ((vehicle.capacity ?? 0) > 0) ...[
                  const SizedBox(height: 12),
                  _buildVehicleDetail(
                    icon: Icons.scale_rounded,
                    label: 'Capacity',
                    value: '${vehicle.capacity?.toStringAsFixed(1)} tons',
                    gradient: AppTheme.secondaryGradient,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditVehicleDialog(context, vehicle),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeleteConfirmation(context, vehicle.id),
                        icon: const Icon(Icons.delete_rounded, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: BorderSide(color: AppTheme.errorColor.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

  Widget _buildVehicleDetail({
    required IconData icon,
    required String label,
    required String value,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleImage(dynamic vehicle, String emoji) {
    final hasImage = vehicle.vehicleImageBase64 != null && 
                     vehicle.vehicleImageBase64.isNotEmpty;
    
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        gradient: vehicle.isAvailable
            ? AppTheme.secondaryGradient
            : LinearGradient(
                colors: [Colors.grey.shade400, Colors.grey.shade500],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: vehicle.isAvailable
                ? AppTheme.secondaryColor.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: hasImage
            ? Builder(builder: (ctx) {
                final bytes = ImageHelper.safeDecodeBytes(vehicle.vehicleImageBase64);
                if (bytes == null) {
                  return Center(child: Text(emoji, style: const TextStyle(fontSize: 28)));
                }
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
                );
              })
            : Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
      ),
    );
  }

  String _getVehicleEmoji(String vehicleType) {
    try {
      return AppConstants.serviceCategories
          .firstWhere((c) => c.value == vehicleType.toLowerCase())
          .emoji;
    } catch (_) {
      return '🚛';
    }
  }

  String _vehicleTypeLabel(String vehicleType) {
    try {
      return AppConstants.serviceCategories
          .firstWhere((c) => c.value == vehicleType.toLowerCase())
          .label;
    } catch (_) {
      return vehicleType
          .split('_')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.local_shipping_rounded,
      title: 'No Vehicles Yet',
      subtitle: 'Add your vehicles to start\nreceiving booking requests',
    );
  }



  void _showAddVehicleDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String? selectedServiceType;
    final numberController = TextEditingController();
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    final ImagePicker picker = ImagePicker();
    String? vehicleImageBase64;
    XFile? selectedImage;
    String? vehicleLicenseImageBase64;
    XFile? licenseDocImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Vehicle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Enter vehicle details',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormSectionHeader('Vehicle Type', Icons.category_rounded),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedServiceType,
                        decoration: InputDecoration(
                          hintText: 'Select vehicle type',
                          filled: true,
                          fillColor: AppTheme.backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.local_shipping_rounded),
                        ),
                        items: AppConstants.serviceCategories
                            .map((cat) => DropdownMenuItem(
                                  value: cat.value,
                                  child: Text('${cat.emoji} ${cat.label}'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          selectedServiceType = value;
                        },
                        validator: (value) =>
                            value == null ? 'Please select vehicle type' : null,
                      ),

                      const SizedBox(height: 24),
                      _buildFormSectionHeader('Vehicle Details', Icons.info_rounded),
                      const SizedBox(height: 12),
                      _buildModernTextField(
                        controller: numberController,
                        label: 'Vehicle Number',
                        hint: 'LHR-1234',
                        icon: Icons.pin_rounded,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: modelController,
                        label: 'Model',
                        hint: 'Enter model name',
                        icon: Icons.directions_car_rounded,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: yearController,
                        label: 'Year',
                        hint: '2023',
                        icon: Icons.calendar_today_rounded,
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      _buildFormSectionHeader('Vehicle Image', Icons.image_rounded),
                      const SizedBox(height: 12),
                      StatefulBuilder(
                        builder: (context, setState) => GestureDetector(
                          onTap: () async {
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 800,
                              maxHeight: 800,
                              imageQuality: 70,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setState(() {
                                selectedImage = image;
                                vehicleImageBase64 = base64Encode(bytes);
                              });
                            }
                          },
                          child: Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: selectedImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        FutureBuilder<Uint8List>(
                                          future: selectedImage!.readAsBytes(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData) {
                                              return Image.memory(
                                                snapshot.data!,
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                              );
                                            }
                                            return const Center(
                                              child: CircularProgressIndicator(),
                                            );
                                          },
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.close, color: Colors.white),
                                              onPressed: () {
                                                setState(() {
                                                  selectedImage = null;
                                                  vehicleImageBase64 = null;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.primaryGradient,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                          Icons.add_photo_alternate_rounded,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Tap to upload vehicle image',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Optional',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildFormSectionHeader('Vehicle Registration Document', Icons.description_rounded),
                      const SizedBox(height: 12),
                      StatefulBuilder(
                        builder: (context, setLicenseState) => GestureDetector(
                          onTap: () async {
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 800,
                              maxHeight: 800,
                              imageQuality: 70,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setLicenseState(() {
                                licenseDocImage = image;
                                vehicleLicenseImageBase64 = base64Encode(bytes);
                              });
                            }
                          },
                          child: Container(
                            height: 140,
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: licenseDocImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        FutureBuilder<Uint8List>(
                                          future: licenseDocImage!.readAsBytes(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData) {
                                              return Image.memory(
                                                snapshot.data!,
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                              );
                                            }
                                            return const Center(child: CircularProgressIndicator());
                                          },
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.close, color: Colors.white),
                                              onPressed: () {
                                                setLicenseState(() {
                                                  licenseDocImage = null;
                                                  vehicleLicenseImageBase64 = null;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.primaryGradient,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(Icons.upload_file_rounded, size: 32, color: Colors.white),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Tap to upload registration document',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Optional',
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      GradientButton(
                        text: 'Add Vehicle',
                        icon: Icons.add_rounded,
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(dialogContext);
                            context.read<ProviderBloc>().add(
                                  ProviderAddVehicleRequested(
                                    vehicleType: selectedServiceType!,
                                    vehicleModel: modelController.text,
                                    vehicleYear: yearController.text,
                                    licensePlate: numberController.text,
                                    capacity: 0.0,
                                    pricePerHour: 0.0,
                                    pricePerKm: 0.0,
                                    imageUrls: const [],
                                    vehicleImageBase64: vehicleImageBase64,
                                    vehicleLicenseImageBase64: vehicleLicenseImageBase64,
                                  ),
                                );
                          }
                        },
                      ),
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

  Widget _buildFormSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppTheme.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  void _showEditVehicleDialog(BuildContext context, vehicle) {
    final formKey = GlobalKey<FormState>();
    final modelController = TextEditingController(text: vehicle.vehicleModel ?? '');
    final yearController = TextEditingController(text: vehicle.vehicleYear ?? '');
    final ImagePicker picker = ImagePicker();
    String? vehicleImageBase64 = vehicle.vehicleImageBase64;
    XFile? selectedImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.secondaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Vehicle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          vehicle.vehicleNumber as String,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Read-only vehicle type chip
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _getVehicleEmoji(vehicle.vehicleType as String),
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _vehicleTypeLabel(vehicle.vehicleType as String),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    vehicle.vehicleNumber as String,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Type fixed',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildFormSectionHeader('Editable Details', Icons.edit_note_rounded),
                      const SizedBox(height: 12),
                      _buildModernTextField(
                        controller: modelController,
                        label: 'Model',
                        hint: 'Enter model name',
                        icon: Icons.directions_car_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: yearController,
                        label: 'Year',
                        hint: '2023',
                        icon: Icons.calendar_today_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      _buildFormSectionHeader('Vehicle Image', Icons.image_rounded),
                      const SizedBox(height: 12),
                      StatefulBuilder(
                        builder: (context, setState) => GestureDetector(
                          onTap: () async {
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 800,
                              maxHeight: 800,
                              imageQuality: 70,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setState(() {
                                selectedImage = image;
                                vehicleImageBase64 = base64Encode(bytes);
                              });
                            }
                          },
                          child: Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: selectedImage != null || vehicleImageBase64 != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        if (selectedImage != null)
                                          FutureBuilder<Uint8List>(
                                            future: selectedImage!.readAsBytes(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return const Center(
                                                child: CircularProgressIndicator(),
                                              );
                                            },
                                          )
                                        else if (vehicleImageBase64 != null)
                                          Builder(builder: (_) {
                                            final bytes = ImageHelper.safeDecodeBytes(vehicleImageBase64);
                                            if (bytes == null) return const SizedBox.shrink();
                                            return Image.memory(
                                              bytes,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                            );
                                          }),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.white),
                                              onPressed: () async {
                                                final XFile? image = await picker.pickImage(
                                                  source: ImageSource.gallery,
                                                  maxWidth: 800,
                                                  maxHeight: 800,
                                                  imageQuality: 70,
                                                );
                                                if (image != null) {
                                                  final bytes = await image.readAsBytes();
                                                  setState(() {
                                                    selectedImage = image;
                                                    vehicleImageBase64 = base64Encode(bytes);
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.secondaryGradient,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                          Icons.add_photo_alternate_rounded,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Tap to upload vehicle image',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      GradientButton(
                        text: 'Save Changes',
                        icon: Icons.save_rounded,
                        gradient: AppTheme.secondaryGradient,
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          final Map<String, dynamic> updates = {
                            'vehicleModel': modelController.text,
                            'vehicleYear': yearController.text,
                          };
                          if (vehicleImageBase64 != null &&
                              vehicleImageBase64 != vehicle.vehicleImageBase64) {
                            updates['vehicleImageBase64'] = vehicleImageBase64;
                          }
                          context.read<ProviderBloc>().add(
                                ProviderUpdateVehicleRequested(
                                  vehicleId: vehicle.id as String,
                                  updates: updates,
                                ),
                              );
                        },
                      ),
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

  void _showDeleteConfirmation(BuildContext context, String vehicleId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AppTheme.errorColor),
            ),
            const SizedBox(width: 12),
            const Text('Delete Vehicle'),
          ],
        ),
        content: const Text('Are you sure you want to delete this vehicle? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ProviderBloc>().add(
                    ProviderDeleteVehicleRequested(vehicleId: vehicleId),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Pattern painter for vehicle screen
class VehiclePatternPainter extends CustomPainter {
  final Color color;

  VehiclePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw diagonal lines
    for (double i = -size.height; i < size.width + size.height; i += 30) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
