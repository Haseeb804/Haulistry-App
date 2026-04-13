import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/graphql_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../booking/data/datasources/booking_remote_datasource.dart';
import '../../../booking/data/repositories/booking_repository_impl.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../feedback/data/datasources/feedback_remote_datasource.dart';
import '../../../feedback/data/repositories/feedback_repository_impl.dart';
import '../../domain/entities/service_entity.dart';
import '../bloc/service_bloc.dart';
import '../bloc/service_event.dart';
import '../bloc/service_state.dart';

class SeekerHomeScreen extends StatefulWidget {
  const SeekerHomeScreen({super.key});

  @override
  State<SeekerHomeScreen> createState() => _SeekerHomeScreenState();
}

class _SeekerHomeScreenState extends State<SeekerHomeScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late BookingRepositoryImpl _bookingRepository;
  late FeedbackRepositoryImpl _feedbackRepository;
  String _selectedCategory = 'All';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  bool _feedbackGateChecked = false;

  // Categories that match backend service categories
  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.apps_rounded, 'emoji': '🔷', 'keywords': []},
    {'name': 'Trolley', 'icon': Icons.local_shipping_rounded, 'emoji': '🚛', 'keywords': ['trolley', 'sand_trolley', 'bricks_trolley']},
    {'name': 'Harvester', 'icon': Icons.agriculture_rounded, 'emoji': '🌾', 'keywords': ['harvester']},
    {'name': 'Crane', 'icon': Icons.construction_rounded, 'emoji': '🏗️', 'keywords': ['crane']},
    {'name': 'Tractor', 'icon': Icons.agriculture_rounded, 'emoji': '🚜', 'keywords': ['tractor']},
    {'name': 'Excavator', 'icon': Icons.precision_manufacturing_rounded, 'emoji': '⛏️', 'keywords': ['excavator']},
    {'name': 'Loader', 'icon': Icons.landscape_rounded, 'emoji': '🚧', 'keywords': ['loader']},
    {'name': 'Mixer', 'icon': Icons.blender_rounded, 'emoji': '🔄', 'keywords': ['mixer', 'concrete_mixer']},
    {'name': 'Dumper', 'icon': Icons.local_shipping_rounded, 'emoji': '🚚', 'keywords': ['dumper']},
    {'name': 'Tanker', 'icon': Icons.water_drop_rounded, 'emoji': '💧', 'keywords': ['tanker', 'water_tanker']},
  ];

  /// Check if a service matches the selected category
  bool _serviceMatchesCategory(ServiceEntity service, String categoryName) {
    if (categoryName == 'All') return true;
    
    final category = _categories.firstWhere(
      (c) => c['name'] == categoryName,
      orElse: () => {'name': categoryName, 'keywords': []},
    );
    
    final keywords = (category['keywords'] as List<dynamic>).cast<String>();
    final serviceCategory = service.category.toLowerCase();
    final vehicleType = (service.vehicleType ?? '').toLowerCase();
    final serviceName = service.name.toLowerCase();
    
    // Check if any keyword matches
    for (final keyword in keywords) {
      if (serviceCategory.contains(keyword) ||
          vehicleType.contains(keyword) ||
          serviceName.contains(keyword)) {
        return true;
      }
    }
    
    // Fallback: check if category name is contained in service data
    final catLower = categoryName.toLowerCase();
    return serviceCategory.contains(catLower) ||
           vehicleType.contains(catLower) ||
           serviceName.contains(catLower);
  }

  @override
  void initState() {
    super.initState();
    _bookingRepository = BookingRepositoryImpl(
      remoteDataSource: BookingRemoteDataSource(
        graphQLClient: GraphQLClientService.instance,
      ),
    );
    _feedbackRepository = FeedbackRepositoryImpl(
      remoteDataSource: FeedbackRemoteDataSource(baseUrl: AppConstants.apiUrl),
    );
    context.read<ServiceBloc>().add(const ServiceLoadRequested());
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enforceMandatorySeekerFeedback();
    });
  }

  Future<void> _enforceMandatorySeekerFeedback() async {
    if (_feedbackGateChecked) return;
    _feedbackGateChecked = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final completedBookings = await _bookingRepository.getBookingHistory(
        user.uid,
        status: 'completed',
      );

      completedBookings.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      for (final booking in completedBookings) {
        final providerId = booking.providerId;
        if (providerId == null || providerId.isEmpty) continue;

        final exists = await _feedbackRepository.checkFeedbackExists(booking.id, 'seeker');
        if (!mounted) return;

        if (!exists) {
          context.go('/feedback/seeker', extra: {
            'bookingId': booking.id,
            'providerId': providerId,
            'providerName': booking.providerName ?? 'Provider',
          });
          return;
        }
      }
    } catch (_) {
      // Non-blocking: keep home usable if network check fails.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<ServiceBloc>().add(const ServiceLoadRequested());
        },
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            _buildCategoriesSection(),
            _buildServicesHeader(),
            _buildServicesGrid(),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.secondaryGradient,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good ${_getGreeting()}! 👋',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) {
                              if (state is AuthAuthenticated) {
                                return Text(
                                  state.user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }
                              return const Text(
                                'User',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildAppBarIcon(
                            icon: Icons.notifications_rounded,
                            badge: 2,
                            onTap: () {},
                          ),
                          const SizedBox(width: 12),
                          _buildAppBarIcon(
                            icon: Icons.person_rounded,
                            onTap: () => context.push('/profile'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSearchBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarIcon({
    required IconData icon,
    int? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (badge != null && badge > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppTheme.errorColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for services...',
          hintStyle: const TextStyle(color: AppTheme.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                    context.read<ServiceBloc>().add(const ServiceLoadRequested());
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          setState(() {});
          if (value.isEmpty) {
            context.read<ServiceBloc>().add(const ServiceLoadRequested());
          } else {
            context.read<ServiceBloc>().add(ServiceSearchRequested(query: value));
          }
        },
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.category_rounded, color: AppTheme.primaryColor, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Browse Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category['name'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = category['name']);
                      context.read<ServiceBloc>().add(
                            ServiceFilterByCategory(category: category['name']),
                          );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppTheme.primaryGradient : null,
                        color: isSelected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : AppTheme.softShadow,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(category['emoji'], style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 6),
                          Text(
                            category['name'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Row(
          children: [
            const Icon(Icons.local_offer_rounded,
                color: AppTheme.secondaryColor, size: 22),
            const SizedBox(width: 8),
            Text(
              _selectedCategory == 'All'
                  ? 'Available Services'
                  : '$_selectedCategory Services',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesGrid() {
    return BlocBuilder<ServiceBloc, ServiceState>(
      builder: (context, state) {
        if (state is ServiceLoading) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.secondaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Finding services for you...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is ServiceError) {
          return SliverFillRemaining(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Oops! Something went wrong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<ServiceBloc>().add(const ServiceLoadRequested());
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is ServiceLoaded) {
          if (state.services.isEmpty) {
            return SliverFillRemaining(
              child: Center(
                child: EmptyStateWidget(
                  icon: Icons.search_off_rounded,
                  title: 'No Services Available',
                  subtitle: 'No verified providers have listed services yet.\nCheck back later!',
                ),
              ),
            );
          }

          // Filter services based on selected category using the matching function
          final filteredServices = state.services
              .where((service) => _serviceMatchesCategory(service, _selectedCategory))
              .toList();

          if (filteredServices.isEmpty) {
            return SliverFillRemaining(
              child: Center(
                child: EmptyStateWidget(
                  icon: Icons.category_outlined,
                  title: 'No $_selectedCategory Services',
                  subtitle: 'No services available in this category.\nTry selecting a different category.',
                ),
              ),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final service = filteredServices[index];
                  return _buildServiceCard(service);
                },
                childCount: filteredServices.length,
              ),
            ),
          );
        }

        return SliverFillRemaining(
          child: Center(
            child: EmptyStateWidget(
              icon: Icons.hourglass_empty_rounded,
              title: 'Loading...',
              subtitle: 'Please wait',
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceCard(ServiceEntity service) {
    final categoryData = _getCategoryData(service.category);

    return GestureDetector(
      onTap: () => _navigateToBooking(service),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Header with Vehicle Image
            Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: categoryData['gradient'] as LinearGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  // Background pattern
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ServicePatternPainter(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  // Vehicle image or emoji
                  Center(
                    child: service.vehicleImageBase64 != null &&
                            service.vehicleImageBase64!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(service.vehicleImageBase64!),
                              width: 120,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Text(
                                categoryData['emoji'] as String,
                                style: const TextStyle(fontSize: 56),
                              ),
                            ),
                          )
                        : Text(
                            categoryData['emoji'] as String,
                            style: const TextStyle(fontSize: 56),
                          ),
                  ),
                  // Rating badge
                  if (service.providerRating != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              service.providerRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Category tag
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        service.category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Service Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service name and price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Rs. ${service.basePrice.toStringAsFixed(0)}+',
                          style: const TextStyle(
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (service.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      service.description!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Provider info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: service.providerImageUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  service.providerImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.providerName ?? 'Provider',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.local_shipping_rounded,
                                    size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  '${service.vehicleType ?? 'Vehicle'} • ${service.vehicleNumber ?? ''}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Book button
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _navigateToBooking(service),
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                'Book',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Pricing info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPriceItem(
                          'Base',
                          'Rs. ${service.basePrice.toStringAsFixed(0)}',
                          Icons.attach_money_rounded,
                        ),
                        Container(
                          height: 30,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        _buildPriceItem(
                          'Per KM',
                          'Rs. ${service.pricePerKm.toStringAsFixed(0)}',
                          Icons.route_rounded,
                        ),
                        Container(
                          height: 30,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        _buildPriceItem(
                          'Per Hour',
                          'Rs. ${service.pricePerHour.toStringAsFixed(0)}',
                          Icons.access_time_rounded,
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
    );
  }

  Widget _buildPriceItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  void _navigateToBooking(ServiceEntity service) {
    // Navigate to booking screen with service data
    context.push('/booking/create', extra: service);
  }

  Widget _buildFAB() {
    return Container(
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
        onPressed: () => context.push('/seeker/history'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.history_rounded, color: Colors.white),
        label: const Text(
          'My Bookings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Map<String, dynamic> _getCategoryData(String category) {
    final lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('trolley') || lowerCategory.contains('sand') ||
        lowerCategory.contains('brick')) {
      return {'emoji': '🚛', 'gradient': AppTheme.primaryGradient};
    } else if (lowerCategory.contains('harvester') || lowerCategory.contains('tractor')) {
      return {'emoji': '🌾', 'gradient': AppTheme.secondaryGradient};
    } else if (lowerCategory.contains('crane')) {
      return {'emoji': '🏗️', 'gradient': AppTheme.accentGradient};
    } else if (lowerCategory.contains('excavator')) {
      return {
        'emoji': '🚜',
        'gradient': const LinearGradient(colors: [Color(0xFFE17055), Color(0xFFD63031)])
      };
    } else if (lowerCategory.contains('loader') || lowerCategory.contains('bulldozer')) {
      return {
        'emoji': '🚧',
        'gradient': const LinearGradient(colors: [Color(0xFFFDAA4F), Color(0xFFFFB347)])
      };
    } else if (lowerCategory.contains('mixer') || lowerCategory.contains('concrete')) {
      return {
        'emoji': '🔄',
        'gradient': const LinearGradient(colors: [Color(0xFF636e72), Color(0xFF2d3436)])
      };
    } else if (lowerCategory.contains('dumper') || lowerCategory.contains('tanker')) {
      return {
        'emoji': '🚰',
        'gradient': const LinearGradient(colors: [Color(0xFF0984e3), Color(0xFF74b9ff)])
      };
    }

    return {'emoji': '🚛', 'gradient': AppTheme.primaryGradient};
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

// Pattern painter for service cards
class ServicePatternPainter extends CustomPainter {
  final Color color;

  ServicePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double i = 0; i < size.width + size.height; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(0, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
