import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../../../core/data/graphql_client.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  late BookingRepositoryImpl _repository;
  List<BookingEntity> _bookings = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';
  String? _userRole;

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
    _getUserRole();
    _loadBookings();
  }

  void _getUserRole() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _userRole = authState.user.role;
    }
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

  bool get _isProvider => _userRole == AppConstants.roleProvider;

  void _navigateToTracking(BookingEntity booking) {
    LatLng? pickupLocation;
    LatLng? dropoffLocation;
    
    if (booking.pickupLatitude != null && booking.pickupLongitude != null) {
      pickupLocation = LatLng(booking.pickupLatitude!, booking.pickupLongitude!);
    }
    if (booking.dropLatitude != null && booking.dropLongitude != null) {
      dropoffLocation = LatLng(booking.dropLatitude!, booking.dropLongitude!);
    }
    
    // Check user role to determine which tracking screen to use
    final authState = context.read<AuthBloc>().state;
    final isProvider = authState is AuthAuthenticated && 
        authState.user.role == AppConstants.roleProvider;
    
    if (isProvider) {
      // Navigate to provider tracking screen
      context.push(
        '/provider/tracking/${booking.id}',
        extra: {
          'pickupLocation': pickupLocation,
          'dropoffLocation': dropoffLocation,
          'pickupAddress': booking.pickupAddress,
          'dropAddress': booking.dropAddress,
          'estimatedPrice': booking.estimatedPrice,
          'serviceType': booking.serviceType,
          'bookingStatus': booking.status,
          'seekerName': booking.seekerName,
        },
      );
    } else {
      // Navigate to seeker tracking screen
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
          'bookingStatus': booking.status,
          'providerName': booking.providerName ?? 'Provider',
        },
      );
    }
  }

  void _navigateToFeedback(BookingEntity booking) {
    if (_isProvider) {
      // Provider rating seeker
      context.push('/feedback/provider', extra: {
        'bookingId': booking.id,
        'seekerId': booking.seekerId,
        'seekerName': booking.seekerName ?? 'Customer',
      });
    } else {
      // Seeker rating provider
      context.push('/feedback/seeker', extra: {
        'bookingId': booking.id,
        'providerId': booking.providerId ?? '',
        'providerName': booking.providerName ?? 'Provider',
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppTheme.successColor;
      case 'in_progress':
        return AppTheme.primaryColor;
      case 'accepted':
        return AppTheme.secondaryColor;
      case 'cancelled':
      case 'rejected':
        return AppTheme.errorColor;
      case 'pending':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  LinearGradient _getStatusGradient(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppTheme.secondaryGradient;
      case 'in_progress':
        return AppTheme.primaryGradient;
      case 'accepted':
        return const LinearGradient(colors: [Color(0xFF0984e3), Color(0xFF74b9ff)]);
      case 'cancelled':
      case 'rejected':
        return const LinearGradient(colors: [Color(0xFFe17055), Color(0xFFd63031)]);
      case 'pending':
        return const LinearGradient(colors: [Color(0xFFFDAA4F), Color(0xFFFFB347)]);
      default:
        return AppTheme.primaryGradient;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'in_progress':
        return Icons.local_shipping_rounded;
      case 'accepted':
        return Icons.thumb_up_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'rejected':
        return Icons.block_rounded;
      default:
        return Icons.pending_rounded;
    }
  }

  String _getServiceEmoji(String serviceType) {
    final type = serviceType.toLowerCase();
    if (type.contains('trolley') || type.contains('sand') || type.contains('brick')) return '🚛';
    if (type.contains('harvester')) return '🌾';
    if (type.contains('tractor')) return '🚜';
    if (type.contains('crane')) return '🏗️';
    if (type.contains('excavator')) return '⚙️';
    if (type.contains('loader')) return '🚧';
    if (type.contains('dumper')) return '⬇️';
    if (type.contains('mixer') || type.contains('concrete')) return '🔄';
    if (type.contains('tanker')) return '🚰';
    return '🚛';
  }

  Widget _buildBookingCard(BookingEntity booking) {
    final statusGradient = _getStatusGradient(booking.status);
    final statusColor = _getStatusColor(booking.status);
    final emoji = _getServiceEmoji(booking.serviceType);
    
    // Determine the other party's name based on user role
    final otherPartyName = _isProvider 
        ? (booking.seekerName ?? 'Customer')
        : (booking.providerName ?? 'Provider');
    final otherPartyLabel = _isProvider ? 'Customer' : 'Provider';

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
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Header with gradient
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
                        gradient: statusGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
                          Row(
                            children: [
                              Icon(
                                _isProvider ? Icons.person_rounded : Icons.local_shipping_rounded,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$otherPartyLabel: $otherPartyName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM d, yyyy • h:mm a').format(booking.scheduledDateTime),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: statusGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(booking.status),
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            booking.status.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
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
                        Expanded(child: _buildDetailChip(Icons.straighten_rounded, '${booking.distanceInKm.toStringAsFixed(1)} km')),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDetailChip(Icons.schedule_rounded, '${booking.hours}h')),
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
                    
                    // Action Buttons
                    Row(
                      children: [
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
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: statusGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _navigateToTracking(booking),
                                borderRadius: BorderRadius.circular(10),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.map_rounded, size: 16, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text(
                                        'View Route',
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

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 140,
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: HistoryPatternPainter(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Booking History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_bookings.length} bookings found',
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

          // Filter Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter['value'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter['value'];
                        });
                        _loadBookings();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppTheme.accentGradient : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
                              ? [BoxShadow(
                                  color: AppTheme.accentColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )]
                              : AppTheme.softShadow,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              filter['icon'],
                              size: 18,
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              filter['label'],
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Content
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading bookings...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: AppTheme.errorColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Error loading bookings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      GradientButton(
                        text: 'Try Again',
                        icon: Icons.refresh_rounded,
                        gradient: AppTheme.accentGradient,
                        onPressed: _loadBookings,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_bookings.isEmpty)
            SliverFillRemaining(
              child: EmptyStateWidget(
                icon: Icons.inbox_rounded,
                title: 'No Bookings Yet',
                subtitle: 'Your booking history\nwill appear here',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildBookingCard(_bookings[index]),
                childCount: _bookings.length,
              ),
            ),

          // Bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

// Pattern painter
class HistoryPatternPainter extends CustomPainter {
  final Color color;
  HistoryPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double i = 0; i < size.width; i += 40) {
      for (double j = 0; j < size.height; j += 40) {
        canvas.drawCircle(Offset(i, j), 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
