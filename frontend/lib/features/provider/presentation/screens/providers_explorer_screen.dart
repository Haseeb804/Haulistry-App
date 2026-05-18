import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';

class ProvidersExplorerScreen extends StatefulWidget {
  const ProvidersExplorerScreen({super.key});

  @override
  State<ProvidersExplorerScreen> createState() =>
      _ProvidersExplorerScreenState();
}

class _ProvidersExplorerScreenState extends State<ProvidersExplorerScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _providers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _activeFilter = 'Top Rated';
  int _offset = 0;
  static const _pageSize = 20;
  bool _hasMore = true;

  final List<String> _filters = [
    'Top Rated',
    'Lowest Fare',
    'Most Booked',
    'Most Reviewed',
  ];

  @override
  void initState() {
    super.initState();
    _fetchProviders(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _fetchMore();
    }
  }

  Future<void> _fetchProviders({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _providers = [];
        _filtered = [];
        _offset = 0;
        _hasMore = true;
      });
    }
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final resp = await ApiService.instance.exploreProviders(
        requesterId: uid,
        limit: _pageSize,
        offset: reset ? 0 : _offset,
      );
      final List<dynamic> raw =
          (resp['providers'] as List<dynamic>?) ?? [];
      final list = raw
          .whereType<Map<String, dynamic>>()
          .toList();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _providers = list;
        } else {
          _providers = [..._providers, ...list];
        }
        _offset = _providers.length;
        _hasMore = list.length >= _pageSize;
        _loading = false;
        _applyFiltersAndSearch();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load providers. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _fetchMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final resp = await ApiService.instance.exploreProviders(
        requesterId: uid,
        limit: _pageSize,
        offset: _offset,
      );
      final List<dynamic> raw =
          (resp['providers'] as List<dynamic>?) ?? [];
      final list = raw.whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      setState(() {
        _providers = [..._providers, ...list];
        _offset = _providers.length;
        _hasMore = list.length >= _pageSize;
        _loadingMore = false;
        _applyFiltersAndSearch();
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _applyFiltersAndSearch() {
    final query = _searchController.text.trim().toLowerCase();
    List<Map<String, dynamic>> result = List.from(_providers);

    // Search
    if (query.isNotEmpty) {
      result = result.where((p) {
        final name = (p['name'] as String? ?? '').toLowerCase();
        final services = (p['services'] as List<dynamic>?) ?? [];
        final serviceMatch = services.any((s) {
          final sName = ((s as Map)['name'] as String? ?? '').toLowerCase();
          return sName.contains(query);
        });
        return name.contains(query) || serviceMatch;
      }).toList();
    }

    // Sort by active filter
    switch (_activeFilter) {
      case 'Top Rated':
        result.sort((a, b) =>
            ((b['rating'] as num?) ?? 0).compareTo((a['rating'] as num?) ?? 0));
        break;
      case 'Lowest Fare':
        result.sort((a, b) {
          final aMin = _minFare(a);
          final bMin = _minFare(b);
          return aMin.compareTo(bMin);
        });
        break;
      case 'Most Booked':
        result.sort((a, b) =>
            ((b['completedBookings'] as num?) ?? 0)
                .compareTo((a['completedBookings'] as num?) ?? 0));
        break;
      case 'Most Reviewed':
        result.sort((a, b) =>
            ((b['totalReviews'] as num?) ?? 0)
                .compareTo((a['totalReviews'] as num?) ?? 0));
        break;
    }

    setState(() => _filtered = result);
  }

  double _minFare(Map<String, dynamic> provider) {
    final services = (provider['services'] as List<dynamic>?) ?? [];
    if (services.isEmpty) return double.maxFinite;
    double min = double.maxFinite;
    for (final s in services) {
      final base = ((s as Map)['basePrice'] as num?)?.toDouble() ?? 0.0;
      if (base > 0 && base < min) min = base;
    }
    return min;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(innerBoxIsScrolled),
        ],
        body: Column(
          children: [
            _buildFilterChips(),
            Expanded(
              child: _loading
                  ? _buildShimmerList()
                  : _error != null
                      ? _buildError()
                      : _filtered.isEmpty
                          ? _buildEmpty()
                          : _buildProviderList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      expandedHeight: 130,
      elevation: innerBoxIsScrolled ? 4 : 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFE55A2B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
              child: _buildSearchBar(),
            ),
          ),
        ),
        title: const Text(
          'Explore Providers',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _applyFiltersAndSearch(),
        decoration: InputDecoration(
          hintText: 'Search providers or services…',
          hintStyle:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.primaryColor, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppTheme.textSecondary, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _applyFiltersAndSearch();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isActive = _activeFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _activeFilter = filter);
                  _applyFiltersAndSearch();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: isActive ? AppTheme.primaryGradient : null,
                    color: isActive ? null : const Color(0xFFF1F3F8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _filterIcon(filter),
                        size: 14,
                        color: isActive
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        filter,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _filterIcon(String filter) {
    switch (filter) {
      case 'Top Rated':
        return Icons.star_rounded;
      case 'Lowest Fare':
        return Icons.payments_rounded;
      case 'Most Booked':
        return Icons.trending_up_rounded;
      case 'Most Reviewed':
        return Icons.reviews_rounded;
      default:
        return Icons.filter_list_rounded;
    }
  }

  Widget _buildProviderList() {
    return RefreshIndicator(
      onRefresh: () => _fetchProviders(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _filtered.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filtered.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildProviderCard(_filtered[index]);
        },
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    final name = provider['name'] as String? ?? 'Provider';
    final imageUrl = provider['profileImageUrl'] as String?;
    final rating = (provider['rating'] as num?)?.toDouble() ?? 0.0;
    final reviews = (provider['totalReviews'] as num?)?.toInt() ?? 0;
    final completed = (provider['completedBookings'] as num?)?.toInt() ?? 0;
    final city = provider['city'] as String?;
    final experience = provider['experience'] as String?;
    final isOnline = provider['isOnline'] as bool? ?? false;
    final services = (provider['services'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    _buildAvatar(imageUrl, name),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _buildStars(rating),
                          const SizedBox(width: 6),
                          Text(
                            '${rating.toStringAsFixed(1)} ($reviews reviews)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (city != null && city.isNotEmpty)
                            _buildBadge(
                                Icons.location_on_outlined, city, AppTheme.infoColor),
                          if (experience != null && experience.isNotEmpty)
                            _buildBadge(Icons.work_outline_rounded, experience,
                                AppTheme.accentColor),
                          _buildBadge(
                              Icons.check_circle_outline_rounded,
                              '$completed jobs',
                              AppTheme.successColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Services
          if (services.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                'Services (${services.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: services.length,
                itemBuilder: (context, i) =>
                    _buildServiceChip(services[i] as Map<String, dynamic>),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String? imageUrl, String name) {
    const double size = 54;
    final provider = ImageHelper.providerFor(imageUrl);
    if (provider != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image(
          image: provider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialAvatar(name, size),
        ),
      );
    }
    return _buildInitialAvatar(name, size);
  }

  Widget _buildInitialAvatar(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'P',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return const Icon(Icons.star_rounded,
              color: Color(0xFFF9CA24), size: 14);
        } else if (i < rating) {
          return const Icon(Icons.star_half_rounded,
              color: Color(0xFFF9CA24), size: 14);
        }
        return const Icon(Icons.star_outline_rounded,
            color: Color(0xFFDDDDDD), size: 14);
      }),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildServiceChip(Map<String, dynamic> service) {
    final sName = service['name'] as String? ?? 'Service';
    final category = service['category'] as String? ?? '';
    final description = service['description'] as String?;
    final basePrice = (service['basePrice'] as num?)?.toDouble() ?? 0.0;
    final pricePerKm = (service['pricePerKm'] as num?)?.toDouble() ?? 0.0;
    final pricePerHour = (service['pricePerHour'] as num?)?.toDouble() ?? 0.0;
    final vehicleType = service['vehicleType'] as String?;
    final sRating = (service['serviceRating'] as num?)?.toDouble() ?? 0.0;
    final sReviews = (service['serviceReviewCount'] as num?)?.toInt() ?? 0;
    final minLoad = service['minLoad'];
    final maxLoad = service['maxLoad'];
    final loadUnit = service['loadUnit'] as String?;
    final operatingHours = service['operatingHours'] as String?;
    final rawFeatures = service['features'];
    final features = (rawFeatures is List)
        ? rawFeatures.whereType<String>().where((f) => f.isNotEmpty).toList()
        : <String>[];
    final availability = service['availability'] as String?;

    return GestureDetector(
      onTap: () => _showServiceDetailSheet(service),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Name row with rating
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.home_repair_service_rounded,
                      color: AppTheme.primaryColor, size: 13),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Vehicle / Category tag
            if (vehicleType != null && vehicleType.isNotEmpty)
              _serviceTag(Icons.local_shipping_rounded, vehicleType, AppTheme.infoColor)
            else if (category.isNotEmpty)
              _serviceTag(Icons.category_rounded, category, AppTheme.accentColor),
            // Description
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            // Pricing row
            if (basePrice > 0)
              _pricingRow(Icons.payments_rounded, 'Base', 'Rs ${basePrice.toStringAsFixed(0)}'),
            if (pricePerKm > 0)
              _pricingRow(Icons.straighten_rounded, '/km', 'Rs ${pricePerKm.toStringAsFixed(0)}'),
            if (pricePerHour > 0)
              _pricingRow(Icons.access_time_rounded, '/hr', 'Rs ${pricePerHour.toStringAsFixed(0)}'),
            if (basePrice == 0 && pricePerKm == 0 && pricePerHour == 0)
              const Text(
                'Negotiable',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.primaryColor,
                ),
              ),
            // Load capacity
            if (minLoad != null || maxLoad != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.fitness_center_rounded, size: 11, color: AppTheme.textSecondary),
                  const SizedBox(width: 3),
                  Text(
                    [
                      if (minLoad != null) 'Min: $minLoad${loadUnit ?? ''}',
                      if (maxLoad != null) 'Max: $maxLoad${loadUnit ?? ''}',
                    ].join('  '),
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
            // Operating hours / availability
            if (operatingHours != null && operatingHours.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 11, color: AppTheme.textSecondary),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      operatingHours,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else if (availability != null && availability.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.event_available_rounded, size: 11, color: AppTheme.textSecondary),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      availability,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // Features
            if (features.isNotEmpty) ...[
              const SizedBox(height: 5),
              Wrap(
                spacing: 4,
                runSpacing: 3,
                children: features.take(3).map((f) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    f,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
            ],
            // Rating footer
            if (sRating > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF9CA24), size: 12),
                  const SizedBox(width: 2),
                  Text(
                    '${sRating.toStringAsFixed(1)} ($sReviews)',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _serviceTag(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _pricingRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 10, color: AppTheme.primaryColor),
          const SizedBox(width: 3),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showServiceDetailSheet(Map<String, dynamic> service) {
    final sName = service['name'] as String? ?? 'Service';
    final category = service['category'] as String? ?? '';
    final description = service['description'] as String?;
    final basePrice = (service['basePrice'] as num?)?.toDouble() ?? 0.0;
    final pricePerKm = (service['pricePerKm'] as num?)?.toDouble() ?? 0.0;
    final pricePerHour = (service['pricePerHour'] as num?)?.toDouble() ?? 0.0;
    final vehicleType = service['vehicleType'] as String?;
    final vehicleNumber = service['vehicleNumber'] as String?;
    final sRating = (service['serviceRating'] as num?)?.toDouble() ?? 0.0;
    final sReviews = (service['serviceReviewCount'] as num?)?.toInt() ?? 0;
    final minLoad = service['minLoad'];
    final maxLoad = service['maxLoad'];
    final loadUnit = service['loadUnit'] as String?;
    final operatingHours = service['operatingHours'] as String?;
    final rawFeatures = service['features'];
    final features = (rawFeatures is List)
        ? rawFeatures.whereType<String>().where((f) => f.isNotEmpty).toList()
        : <String>[];
    final availability = service['availability'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.home_repair_service_rounded,
                              color: AppTheme.primaryColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              if (vehicleType != null && vehicleType.isNotEmpty)
                                Text(vehicleType,
                                    style: const TextStyle(
                                        color: AppTheme.infoColor, fontSize: 13))
                              else if (category.isNotEmpty)
                                Text(category,
                                    style: const TextStyle(
                                        color: AppTheme.accentColor, fontSize: 13)),
                            ],
                          ),
                        ),
                        if (sRating > 0)
                          Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: Color(0xFFF9CA24), size: 18),
                                  const SizedBox(width: 2),
                                  Text(
                                    sRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              Text(
                                '$sReviews reviews',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Description
                    if (description != null && description.isNotEmpty) ...[
                      _sheetSectionTitle('Description'),
                      Text(
                        description,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 14),
                    ],
                    // Pricing
                    _sheetSectionTitle('Pricing'),
                    _sheetDetailRow(Icons.payments_rounded, 'Base Price',
                        basePrice > 0 ? 'Rs ${basePrice.toStringAsFixed(0)}' : 'Negotiable'),
                    if (pricePerKm > 0)
                      _sheetDetailRow(Icons.straighten_rounded, 'Per Km',
                          'Rs ${pricePerKm.toStringAsFixed(0)}'),
                    if (pricePerHour > 0)
                      _sheetDetailRow(Icons.access_time_rounded, 'Per Hour',
                          'Rs ${pricePerHour.toStringAsFixed(0)}'),
                    const SizedBox(height: 14),
                    // Vehicle
                    if (vehicleType != null || vehicleNumber != null) ...[
                      _sheetSectionTitle('Vehicle'),
                      if (vehicleType != null && vehicleType.isNotEmpty)
                        _sheetDetailRow(Icons.local_shipping_rounded, 'Type', vehicleType),
                      if (vehicleNumber != null && vehicleNumber.isNotEmpty)
                        _sheetDetailRow(Icons.pin_rounded, 'Number', vehicleNumber),
                      const SizedBox(height: 14),
                    ],
                    // Capacity
                    if (minLoad != null || maxLoad != null) ...[
                      _sheetSectionTitle('Load Capacity'),
                      if (minLoad != null)
                        _sheetDetailRow(Icons.arrow_downward_rounded, 'Minimum',
                            '$minLoad ${loadUnit ?? ''}'),
                      if (maxLoad != null)
                        _sheetDetailRow(Icons.arrow_upward_rounded, 'Maximum',
                            '$maxLoad ${loadUnit ?? ''}'),
                      const SizedBox(height: 14),
                    ],
                    // Schedule
                    if (operatingHours != null && operatingHours.isNotEmpty) ...[
                      _sheetSectionTitle('Operating Hours'),
                      _sheetDetailRow(Icons.schedule_rounded, 'Hours', operatingHours),
                      const SizedBox(height: 14),
                    ] else if (availability != null && availability.isNotEmpty) ...[
                      _sheetSectionTitle('Availability'),
                      _sheetDetailRow(Icons.event_available_rounded, 'Schedule', availability),
                      const SizedBox(height: 14),
                    ],
                    // Features
                    if (features.isNotEmpty) ...[
                      _sheetSectionTitle('Features & Offerings'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: features.map((f) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppTheme.successColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 13, color: AppTheme.successColor),
                              const SizedBox(width: 5),
                              Text(
                                f,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.successColor,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _sheetDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: 5,
      itemBuilder: (_, __) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shimmerBox(54, 54, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(16, 120),
                    const SizedBox(height: 8),
                    _shimmerBox(12, 80),
                    const SizedBox(height: 6),
                    _shimmerBox(12, 160),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _shimmerBox(80, 130),
              const SizedBox(width: 8),
              _shimmerBox(80, 130),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(double height, double width, {double radius = 8}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 900),
      builder: (_, value, __) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFFE8ECF0),
            const Color(0xFFF8F9FD),
            value,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppTheme.textMuted, size: 64),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _fetchProviders(reset: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded,
                  color: AppTheme.primaryColor, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'No providers found',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try changing your search or filter to discover more providers',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            if (_searchController.text.isNotEmpty) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _applyFiltersAndSearch();
                },
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear search'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
