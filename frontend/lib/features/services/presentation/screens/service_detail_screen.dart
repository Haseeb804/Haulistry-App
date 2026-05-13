import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../booking/domain/models/booking_mode_config.dart';
import '../../domain/entities/service_entity.dart';

class ServiceDetailScreen extends StatelessWidget {
  final String serviceType;

  /// When navigated from the seeker home screen with a real provider listing,
  /// carries all provider-configured data including extraFields.
  final ServiceEntity? service;

  const ServiceDetailScreen({
    super.key,
    required this.serviceType,
    this.service,
  });

  // Resolve label ("Sand Trolley") or value ("sand_trolley") → value
  String get _serviceKey {
    final byValue = AppConstants.serviceCategories
        .where((c) => c.value == serviceType)
        .firstOrNull;
    if (byValue != null) return byValue.value;
    final byLabel = AppConstants.serviceCategories
        .where((c) => c.label == serviceType)
        .firstOrNull;
    return byLabel?.value ?? 'other';
  }

  String get _serviceLabel {
    final byValue = AppConstants.serviceCategories
        .where((c) => c.value == serviceType)
        .firstOrNull;
    if (byValue != null) return byValue.label;
    final byLabel = AppConstants.serviceCategories
        .where((c) => c.label == serviceType)
        .firstOrNull;
    return byLabel?.label ?? serviceType;
  }

  @override
  Widget build(BuildContext context) {
    final key = _serviceKey;
    final label = _serviceLabel;
    final config = getBookingModeConfig(key);
    final baseRate =
        AppConstants.baseRates[label] ?? AppConstants.baseRates['Other'] ?? 50.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(key, label, config),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── PROVIDER CARD (real listing) ───────────────────────────
                  if (service != null) ...[
                    _buildProviderCard(service!),
                    const SizedBox(height: 20),
                  ] else ...[
                    Row(
                      children: [
                        _ratingBadge('4.8'),
                        const SizedBox(width: 12),
                        _availabilityBadge('15 providers available'),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── PRICING ────────────────────────────────────────────────
                  service != null
                      ? _buildRealPricingCard(service!, config)
                      : _buildGenericPricingCard(config, baseRate),
                  const SizedBox(height: 20),

                  // ── MACHINE SPECS from provider extraFields ────────────────
                  if (service != null) ...[
                    _buildMachineSpecsCard(service!),
                    const SizedBox(height: 20),
                  ],

                  // ── WHAT'S INCLUDED (boolean extraFields) ─────────────────
                  if (service != null) ...[
                    _buildIncludedFeaturesCard(service!),
                    const SizedBox(height: 20),
                  ],

                  // ── MACHINE BASE LOCATION MAP ──────────────────────────────
                  if ((service?.serviceBaseLatitude ?? service?.providerLatitude) != null &&
                      (service?.serviceBaseLongitude ?? service?.providerLongitude) != null) ...[
                    _buildProviderLocationMap(service!),
                    const SizedBox(height: 20),
                  ],

                  // ── ABOUT ──────────────────────────────────────────────────
                  _sectionTitle(
                      Icons.info_rounded, AppTheme.primaryColor, 'About this service'),
                  const SizedBox(height: 12),
                  Text(
                    service?.description ?? _getServiceDescription(key),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, height: 1.6),
                  ),
                  const SizedBox(height: 24),

                  // ── HOW TO BOOK ────────────────────────────────────────────
                  _buildHowItWorksCard(config),
                  const SizedBox(height: 24),

                  // ── PLATFORM FEATURES ──────────────────────────────────────
                  _sectionTitle(Icons.verified_rounded, AppTheme.secondaryColor,
                      'Platform Features'),
                  const SizedBox(height: 12),
                  _buildFeatureItem('Real-time GPS tracking', Icons.gps_fixed_rounded),
                  _buildFeatureItem('Verified providers', Icons.verified_user_rounded),
                  _buildFeatureItem('Secure payment', Icons.security_rounded),
                  _buildFeatureItem('24/7 support', Icons.support_agent_rounded),
                  _buildFeatureItem('Insurance coverage', Icons.shield_rounded),
                  const SizedBox(height: 24),

                  // ── SIMILAR SERVICES ───────────────────────────────────────
                  _sectionTitle(Icons.category_rounded, AppTheme.accentColor,
                      'Similar Services'),
                  const SizedBox(height: 12),
                  _buildSimilarServices(context, key),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: GradientButton(
          text: 'Book Now',
          icon: Icons.calendar_today_rounded,
          gradient: AppTheme.primaryGradient,
          onPressed: () {
            final authState = context.read<AuthBloc>().state;
            if (authState is! AuthAuthenticated) {
              context.push('/login');
              return;
            }
            if (service != null) {
              context.push(AppRoutes.bookingRequest, extra: service);
            } else {
              context.push('/booking/create', extra: {'serviceType': key});
            }
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ── Sliver App Bar ─────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(
      String key, String label, BookingModeConfig config) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
            onPressed: () => ctx.pop(),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: ServicePatternPainter(
                      color: Colors.white.withOpacity(0.05)),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      _buildHeroWidget(key),
                      const SizedBox(height: 16),
                      Text(
                        service?.name ?? label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _modeTagLabel(config.mode),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
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
    );
  }

  Widget _buildHeroWidget(String key) {
    final bytes = ImageHelper.safeDecodeBytes(service?.vehicleImageBase64);
    if (bytes != null) {
      return Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(_getServiceIcon(key), size: 80, color: Colors.white),
    );
  }

  // ── Provider Card ──────────────────────────────────────────────────────────

  Widget _buildProviderCard(ServiceEntity svc) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.person_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('Service Provider',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                foregroundImage: ImageHelper.providerFor(svc.providerImageUrl),
                onForegroundImageError:
                    svc.providerImageUrl != null ? (_, __) {} : null,
                child: const Icon(Icons.person_rounded,
                    color: AppTheme.primaryColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            svc.providerName ?? 'Service Provider',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    color: AppTheme.successColor,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              const Text('Active',
                                  style: TextStyle(
                                      color: AppTheme.successColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.local_shipping_rounded,
                            size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${svc.vehicleType ?? 'Vehicle'}  •  ${svc.vehicleNumber ?? ''}',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (svc.providerRating != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (int i = 1; i <= 5; i++)
                            Icon(
                              i <= svc.providerRating!
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            '${svc.providerRating!.toStringAsFixed(1)} rating',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Real Pricing Card ──────────────────────────────────────────────────────

  Widget _buildRealPricingCard(ServiceEntity svc, BookingModeConfig config) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Pricing',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),

          if (config.mode == BookingMode.hybrid && config.jobTypes != null) ...[
            for (final jt in config.jobTypes!) ...[
              _buildPricingModelRow(
                label: jt.label,
                unit: _pricingUnitLabel(jt.pricingModel),
                icon: _pricingIcon(jt.pricingModel),
              ),
              if (jt != config.jobTypes!.last)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider()),
            ],
          ] else ...[
            // Highlighted primary rate from the actual listing
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.primaryColor.withOpacity(0.08),
                  AppTheme.secondaryColor.withOpacity(0.05),
                ]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _primaryRateLabel(config.pricingModel),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      svc.pricingSummary(config),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Extra pricing rows from extraFields (mobilization charge, etc.)
          ..._buildExtraPricingRows(svc),

          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Fixed price per provider\'s listing — no hidden charges.',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExtraPricingRows(ServiceEntity svc) {
    final extras = svc.extraFields;
    if (extras == null || extras.isEmpty) return [];

    const extraPricingKeys = {
      'mobilizationCharge', 'mobilization_charge',
      'extraKmCharge', 'extra_km_charge',
      'pricePerKmTransport', 'price_per_km_transport',
      'attachmentCharges', 'attachment_charges',
    };

    final rows = <Widget>[];
    for (final entry in extras.entries) {
      if (!extraPricingKeys.contains(entry.key)) continue;
      final val = entry.value;
      if (val == null || (val is num && val == 0)) continue;

      rows
        ..add(const SizedBox(height: 10))
        ..add(Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_humanizeKey(entry.key),
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
            Text(
              val is num ? 'Rs. ${val.toStringAsFixed(0)}' : val.toString(),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ));
    }
    return rows;
  }

  String _primaryRateLabel(PricingModel model) {
    switch (model) {
      case PricingModel.perAcre:
        return 'Rate per acre';
      case PricingModel.perHour:
        return 'Rate per hour';
      case PricingModel.perTrip:
        return 'Rate per trip';
      case PricingModel.perKm:
        return 'Base + per km';
      case PricingModel.hybrid:
        return 'Combined rate';
    }
  }

  // ── Machine Specifications Card ────────────────────────────────────────────

  Widget _buildMachineSpecsCard(ServiceEntity svc) {
    final specs = _extractSpecEntries(svc.extraFields ?? {});
    if (specs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.secondaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.settings_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Machine Specifications',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final e in specs)
                _buildSpecChip(e.key, e.value),
            ],
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, dynamic>> _extractSpecEntries(
      Map<String, dynamic> fields) {
    const skipKeys = {
      'pricePerAcre', 'price_per_acre', 'pricePerTrip', 'price_per_trip',
      'pricePerHour', 'price_per_hour', 'pricePerKm', 'price_per_km',
      'basePrice', 'base_price', 'mobilizationCharge', 'mobilization_charge',
      'extraKmCharge', 'extra_km_charge', 'hourlyRate', 'hourly_rate',
      'pricePerThousandBricks', 'price_per_thousand_bricks',
      'pricePerKmTransport', 'price_per_km_transport', 'supplyRate',
      'supply_rate', 'attachmentCharges', 'attachment_charges',
      'pricePerAcreByTask',
      'loadingIncluded', 'loading_included', 'unloadingIncluded',
      'unloading_included', 'stackingIncluded', 'stacking_included',
      'cleaningIncluded', 'cleaning_included', 'insuranceIncluded',
      'insurance_included', 'operatorIncluded', 'operator_included',
      'waterOnSite', 'water_on_site',
    };
    return fields.entries
        .where((e) => !skipKeys.contains(e.key) && e.value != null)
        .toList();
  }

  Widget _buildSpecChip(String key, dynamic value) {
    final formatted = _formatSpecValue(value);
    if (formatted == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _humanizeKey(key),
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  String? _formatSpecValue(dynamic value) {
    if (value == null) return null;
    if (value is bool) return null; // handled in features card
    if (value is List) {
      if (value.isEmpty) return null;
      return value.join(', ');
    }
    if (value is num) return value.toString();
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  // ── What's Included Card ───────────────────────────────────────────────────

  Widget _buildIncludedFeaturesCard(ServiceEntity svc) {
    final features = _extractBoolFeatures(svc.extraFields ?? {});
    if (features.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.checklist_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text("What's Included",
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: features.map((e) {
              final yes = e.value == true;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: yes
                      ? AppTheme.successColor.withOpacity(0.08)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: yes
                        ? AppTheme.successColor.withOpacity(0.3)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      yes ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 15,
                      color: yes
                          ? AppTheme.successColor
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _humanizeKey(e.key),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: yes
                            ? AppTheme.successColor
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, dynamic>> _extractBoolFeatures(
      Map<String, dynamic> fields) {
    const featureKeys = {
      'loadingIncluded', 'loading_included',
      'unloadingIncluded', 'unloading_included',
      'stackingIncluded', 'stacking_included',
      'cleaningIncluded', 'cleaning_included',
      'insuranceIncluded', 'insurance_included',
      'operatorIncluded', 'operator_included',
      'waterOnSite', 'water_on_site',
    };
    return fields.entries
        .where((e) => featureKeys.contains(e.key) && e.value != null)
        .toList();
  }

  // ── Provider Base Location Map ─────────────────────────────────────────────

  Widget _buildProviderLocationMap(ServiceEntity svc) {
    // Prefer service-specific base location; fall back to provider's general location.
    final lat = svc.serviceBaseLatitude ?? svc.providerLatitude!;
    final lng = svc.serviceBaseLongitude ?? svc.providerLongitude!;
    final center = LatLng(lat, lng);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Machine Base Location',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        svc.serviceBaseAddress ??
                            'Provider\'s machine dispatch point',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapEndpoints.osmTileTemplate,
                  userAgentPackageName: 'com.haulistry.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
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
                        child: Icon(
                          _getServiceIcon(_serviceKey),
                          color: Colors.white,
                          size: 20,
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

  // ── Generic Pricing Card ───────────────────────────────────────────────────

  Widget _buildGenericPricingCard(BookingModeConfig config, double baseRate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Pricing',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          if (config.mode == BookingMode.hybrid && config.jobTypes != null) ...[
            for (final jt in config.jobTypes!) ...[
              _buildPricingModelRow(
                label: jt.label,
                unit: _pricingUnitLabel(jt.pricingModel),
                icon: _pricingIcon(jt.pricingModel),
              ),
              if (jt != config.jobTypes!.last)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider()),
            ],
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
            _buildPricingNoteRow('Rates set by each provider on their listing'),
          ] else ...[
            _buildPricingRow(
              label: 'Starting rate',
              value: 'Rs. ${baseRate.toStringAsFixed(0)} ${config.pricingUnit}',
              isHighlighted: true,
            ),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            _buildPricingModelRow(
              label: 'Pricing model',
              unit: _pricingUnitLabel(config.pricingModel),
              icon: _pricingIcon(config.pricingModel),
            ),
            if (config.pricingModel == PricingModel.perKm) ...[
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider()),
              _buildPricingRow(
                  label: 'Per km rate',
                  value:
                      'Rs. ${AppConstants.pricePerKm.toStringAsFixed(0)} / km'),
            ],
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            _buildPricingNoteRow(
                'Final price depends on the provider\'s listed rate'),
          ],
        ],
      ),
    );
  }

  Widget _buildPricingRow(
      {required String label,
      required String value,
      bool isHighlighted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlighted ? 16 : 14,
            color:
                isHighlighted ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight:
                isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isHighlighted ? 14 : 10,
            vertical: isHighlighted ? 8 : 6,
          ),
          decoration: BoxDecoration(
            gradient: isHighlighted ? AppTheme.primaryGradient : null,
            color: isHighlighted ? null : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: isHighlighted ? 16 : 14,
              color: isHighlighted ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingModelRow({
    required String label,
    required String unit,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(unit,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingNoteRow(String note) {
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded,
            size: 15, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(note,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
        ),
      ],
    );
  }

  // ── How It Works Card ──────────────────────────────────────────────────────

  Widget _buildHowItWorksCard(BookingModeConfig config) {
    final steps = _getBookingSteps(config);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.secondaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.list_alt_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('How to book',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(steps[i],
                        style:
                            const TextStyle(fontSize: 14, height: 1.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<String> _getBookingSteps(BookingModeConfig config) {
    switch (config.mode) {
      case BookingMode.fieldService:
        return [
          'Pin your field location on the map',
          'Fill in crop type, land area, and any access notes',
          'Review the auto-calculated price',
          'Pick a date and submit your booking request',
        ];
      case BookingMode.onsiteWork:
        return [
          'Pin the work site on the map',
          'Select the task type and estimated hours needed',
          'Review the auto-calculated price',
          'Choose a date and submit your booking request',
        ];
      case BookingMode.pointToPoint:
        return [
          'Set your pickup / source location',
          'Set the delivery destination',
          'Fill in material type and number of trips',
          'Calculate route price and submit your request',
        ];
      case BookingMode.hybrid:
        return [
          'Choose your job type (on-site or transport)',
          'Set the required location(s) based on your choice',
          'Fill in service-specific details',
          'Review or calculate price, then submit',
        ];
    }
  }

  Widget _buildFeatureItem(String feature, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.secondaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(feature,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSimilarServices(BuildContext context, String currentKey) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: AppConstants.serviceCategories.length,
        itemBuilder: (context, index) {
          final cat = AppConstants.serviceCategories[index];
          if (cat.value == currentKey || cat.value == 'other') {
            return const SizedBox();
          }
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () =>
                  context.pushReplacement('/service/${cat.value}'),
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppTheme.primaryColor.withOpacity(0.12),
                    AppTheme.secondaryColor.withOpacity(0.08),
                  ]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_getServiceIcon(cat.value),
                          size: 28, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        cat.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionTitle(IconData icon, Color color, String title) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _ratingBadge(String rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFFC107), Color(0xFFFFD54F)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Text(rating,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _availabilityBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: AppTheme.successColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }

  String _humanizeKey(String key) {
    final s = key.replaceAll('_', ' ');
    final r = s.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    return r
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _modeTagLabel(BookingMode mode) {
    switch (mode) {
      case BookingMode.fieldService:
        return 'Field / Agricultural';
      case BookingMode.onsiteWork:
        return 'On-Site Equipment';
      case BookingMode.pointToPoint:
        return 'Transport Service';
      case BookingMode.hybrid:
        return 'Multi-Mode Service';
    }
  }

  String _pricingUnitLabel(PricingModel model) {
    switch (model) {
      case PricingModel.perAcre:
        return 'Charged per acre harvested / worked';
      case PricingModel.perHour:
        return 'Charged per hour of machine time';
      case PricingModel.perKm:
        return 'Charged per km of route';
      case PricingModel.perTrip:
        return 'Charged per truckload / trip';
      case PricingModel.hybrid:
        return 'Distance + lifting charges combined';
    }
  }

  IconData _pricingIcon(PricingModel model) {
    switch (model) {
      case PricingModel.perAcre:
        return Icons.crop_landscape_rounded;
      case PricingModel.perHour:
        return Icons.schedule_rounded;
      case PricingModel.perKm:
        return Icons.route_rounded;
      case PricingModel.perTrip:
        return Icons.local_shipping_rounded;
      case PricingModel.hybrid:
        return Icons.swap_horiz_rounded;
    }
  }

  IconData _getServiceIcon(String serviceKey) {
    switch (serviceKey) {
      case 'sand_trolley':
        return Icons.local_shipping;
      case 'bricks_trolley':
        return Icons.fire_truck;
      case 'harvester':
        return Icons.agriculture;
      case 'crane':
        return Icons.construction;
      case 'dumper':
        return Icons.directions_bus;
      case 'excavator':
        return Icons.engineering;
      case 'tractor':
        return Icons.departure_board;
      case 'water_tanker':
        return Icons.water_drop;
      case 'loader':
        return Icons.upload_rounded;
      case 'concrete_mixer':
        return Icons.rotate_right_rounded;
      default:
        return Icons.build;
    }
  }

  String _getServiceDescription(String serviceKey) {
    switch (serviceKey) {
      case 'sand_trolley':
        return 'Professional sand transportation from source to your construction site. '
            'Select the sand type, set pickup and delivery points, and specify the number of trips. '
            'Pricing is per truckload — no hidden per-km charges.';
      case 'bricks_trolley':
        return 'Reliable brick transportation from kiln to construction site. '
            'Specify quantity and brick type, set the route, and book by the trip. '
            'Ideal for residential and commercial building projects.';
      case 'harvester':
        return 'Modern combine harvester services with skilled operators for efficient crop harvesting. '
            'Book by the acre — set your field location, select the crop type and area, '
            'and get an instant price estimate. Supports wheat, rice, sugarcane, and more.';
      case 'tractor':
        return 'Versatile tractor services for agricultural field work. '
            'From plowing and tilling to seeding and laser leveling — set your field location, '
            'choose the task and land area, and get acre-based pricing instantly.';
      case 'excavator':
        return 'Professional excavation for foundations, trenching, demolition, and land clearing. '
            'Book by the hour — pin your site, describe the work type, and set the estimated duration. '
            'Operated by certified and experienced machine operators.';
      case 'loader':
        return 'Front-end loader services for material handling at your site. '
            'Load sand, gravel, rubble, grain, or coal into dumpers or containers. '
            'Hourly billing with transparent rate from the provider.';
      case 'concrete_mixer':
        return 'On-site concrete mixing for construction projects of all scales. '
            'Pin your site, specify the number of cement bags and concrete grade, '
            'and book by the hour. Water availability is noted for accurate pricing.';
      case 'dumper':
        return 'Heavy-duty dumper trucks for transporting construction materials, '
            'debris, and excavated earth between locations. '
            'Set pickup and dropoff, select material type and number of trips — priced per load.';
      case 'crane':
        return 'Professional crane services for on-site lifting or heavy cargo transport. '
            'Choose on-site lifting (hourly) for placing steel beams, precast panels, or HVAC units, '
            'or crane+transport (distance-based) for moving heavy machinery between sites.';
      case 'water_tanker':
        return 'Clean water delivery for construction sites, farms, and events. '
            'Choose direct site delivery (per trip) or custom route delivery from a water source. '
            'Multiple tanker capacities available from 3,000 L to 20,000 L.';
      default:
        return 'Professional service with verified providers. '
            'Book now for reliable and timely service delivery at transparent fixed prices.';
    }
  }
}

// ── Pattern Painter ────────────────────────────────────────────────────────────

class ServicePatternPainter extends CustomPainter {
  final Color color;
  ServicePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (double i = 0; i < size.width; i += 35) {
      for (double j = 0; j < size.height; j += 35) {
        canvas.drawCircle(Offset(i, j), 2.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
