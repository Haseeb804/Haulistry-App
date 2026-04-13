import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../../../core/data/graphql_client.dart';

class SeekerBookingHistoryScreen extends StatefulWidget {
  const SeekerBookingHistoryScreen({super.key});

  @override
  State<SeekerBookingHistoryScreen> createState() => _SeekerBookingHistoryScreenState();
}

class _SeekerBookingHistoryScreenState extends State<SeekerBookingHistoryScreen> {
  late BookingRepositoryImpl _repository;
  List<BookingEntity> _bookings = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';

  final List<Map<String, dynamic>> _filters = [
    {'label': 'All', 'value': 'all', 'icon': Icons.all_inclusive_rounded},
    {'label': 'Pending', 'value': 'pending', 'icon': Icons.pending_rounded},
    {'label': 'In Progress', 'value': 'in_progress', 'icon': Icons.sync_rounded},
    {'label': 'Completed', 'value': 'completed', 'icon': Icons.check_circle_rounded},
    {'label': 'Rejected', 'value': 'rejected', 'icon': Icons.block_rounded},
    {'label': 'Cancelled', 'value': 'cancelled', 'icon': Icons.cancel_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _repository = BookingRepositoryImpl(
      remoteDataSource: BookingRemoteDataSource(
        graphQLClient: GraphQLClientService.instance,
      ),
    );
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final bookings = await _repository.getBookingHistory(
        user.uid,
        status: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToTracking(BookingEntity booking) {
    LatLng? pickupLocation;
    LatLng? dropoffLocation;
    
    pickupLocation = LatLng(booking.pickupLatitude, booking.pickupLongitude);
      dropoffLocation = LatLng(booking.dropLatitude, booking.dropLongitude);
  
    context.push(
      '/booking/${booking.id}/tracking',
      extra: {
        'providerId': booking.providerId ?? '',
        'pickupLocation': pickupLocation,
        'dropoffLocation': dropoffLocation,
        'pickupAddress': booking.pickupAddress,
        'dropAddress': booking.dropAddress,
        'estimatedPrice': booking.estimatedPrice,
        'serviceType': booking.serviceType,
        'providerName': booking.providerName,
      },
    );
  }

  void _navigateToFeedback(BookingEntity booking) {
    context.push('/feedback/seeker', extra: {
      'bookingId': booking.id,
      'providerId': booking.providerId ?? '',
      'providerName': booking.providerName ?? 'Provider',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'My Bookings',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 60),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      '${_bookings.length} booking${_bookings.length != 1 ? 's' : ''} found',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Filters
          SliverToBoxAdapter(
            child: Container(
              height: 60,
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter['value'];
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            filter['icon'],
                            size: 16,
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(filter['label']),
                        ],
                      ),
                      selectedColor: AppTheme.primaryColor,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter['value'];
                          _loadBookings();
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Something went wrong',
                  subtitle: _error!,
                  buttonText: 'Retry',
                  onButtonPressed: _loadBookings,
                ),
              ),
            )
          else if (_bookings.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: EmptyStateWidget(
                  icon: Icons.inbox_rounded,
                  title: 'No bookings yet',
                  subtitle: 'Your booking history will appear here',
                  buttonText: 'Find Services',
                  onButtonPressed: () => context.go('/seeker/home'),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildBookingCard(_bookings[index]),
                childCount: _bookings.length,
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BookingEntity booking) {
    final statusColor = _getStatusColor(booking.status);
    final emoji = _getServiceEmoji(booking.serviceType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToTracking(booking),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.1),
                      statusColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.serviceType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (booking.providerName != null)
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 14, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Provider: ${booking.providerName}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        booking.status.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Locations
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.successColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.trip_origin, size: 8, color: Colors.white),
                            ),
                            Container(
                              width: 2,
                              height: 30,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [AppTheme.successColor, AppTheme.errorColor],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.errorColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on, size: 8, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.pickupAddress,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                booking.dropAddress,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.straighten_rounded, size: 14, color: AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  '${booking.distanceInKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  '${booking.hours}h',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'Rs. ${(booking.finalPrice ?? booking.estimatedPrice).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Date and Action Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('MMM d, yyyy • h:mm a').format(booking.scheduledDateTime),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (booking.status == 'completed')
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _navigateToFeedback(booking),
                                borderRadius: BorderRadius.circular(10),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.star_rounded, size: 16, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text(
                                        'Rate Service',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
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
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppTheme.successColor;
      case 'in_progress':
        return AppTheme.infoColor;
      case 'pending':
        return AppTheme.warningColor;
      case 'rejected':
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getServiceEmoji(String serviceType) {
    final type = serviceType.toLowerCase();
    if (type.contains('harvester')) return '🌾';
    if (type.contains('crane')) return '🏗️';
    if (type.contains('tractor')) return '🚜';
    if (type.contains('trolley') || type.contains('sand') || type.contains('brick')) return '🚛';
    if (type.contains('excavator')) return '⛏️';
    if (type.contains('loader')) return '🚧';
    if (type.contains('mixer')) return '🔄';
    if (type.contains('dumper')) return '🚚';
    if (type.contains('tanker')) return '🚰';
    return '🚛';
  }
}
