import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/negotiation_bloc.dart';
import '../bloc/negotiation_event.dart';
import '../bloc/negotiation_state.dart';
import '../../../../core/domain/entities/fare_offer_entity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';
import 'package:go_router/go_router.dart';

/// Screen for seekers to view and respond to fare offers from providers
class FareOffersScreen extends StatefulWidget {
  final String bookingId;
  final double estimatedPrice;

  const FareOffersScreen({
    super.key,
    required this.bookingId,
    required this.estimatedPrice,
  });

  @override
  State<FareOffersScreen> createState() => _FareOffersScreenState();
}

class _FareOffersScreenState extends State<FareOffersScreen> {
  @override
  void initState() {
    super.initState();
    // Load offers for this booking
    context.read<NegotiationBloc>().add(
          LoadBookingOffersRequested(widget.bookingId),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: BlocConsumer<NegotiationBloc, NegotiationState>(
        listener: (context, state) {
          if (state is NegotiationOfferAccepted) {
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
                      child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Offer accepted! Provider is on the way.'),
                  ],
                ),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            context.go(
              '/booking/${widget.bookingId}/status',
              extra: {
                'providerId': state.acceptedOffer.providerId,
                'providerName': state.acceptedOffer.providerName,
                'pickupLocation': state.updatedBooking != null
                    ? {
                        'latitude': state.updatedBooking!.pickupLatitude,
                        'longitude': state.updatedBooking!.pickupLongitude,
                      }
                    : null,
                'dropoffLocation': state.updatedBooking != null
                    ? {
                        'latitude': state.updatedBooking!.dropLatitude,
                        'longitude': state.updatedBooking!.dropLongitude,
                      }
                    : null,
                'pickupAddress': state.updatedBooking?.pickupAddress,
                'dropAddress': state.updatedBooking?.dropAddress,
                'estimatedPrice': state.updatedBooking?.estimatedPrice ?? widget.estimatedPrice,
                'serviceType': state.updatedBooking?.serviceType,
                'bookingStatus': state.updatedBooking?.status,
              },
            );
          } else if (state is NegotiationCounterSent) {
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
                      child: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Counter offer of Rs. ${state.counterPrice.toStringAsFixed(0)} sent'),
                  ],
                ),
                backgroundColor: AppTheme.accentColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            context.read<NegotiationBloc>().add(
                  LoadBookingOffersRequested(widget.bookingId),
                );
          } else if (state is NegotiationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              // Modern App Bar
              SliverAppBar(
                expandedHeight: 200,
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
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      onPressed: () {
                        context.read<NegotiationBloc>().add(
                              LoadBookingOffersRequested(widget.bookingId),
                            );
                      },
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: OffersPatternPainter(color: Colors.white.withOpacity(0.05)),
                          ),
                        ),
                        SafeArea(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.local_offer_rounded, size: 36, color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                const Text('Fare Offers', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                                  child: Text('Estimated: Rs. ${widget.estimatedPrice.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
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
              if (state is NegotiationLoading)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(20)),
                          child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        ),
                        const SizedBox(height: 20),
                        const Text('Loading offers...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              else if (state is NegotiationLoaded && state.offers.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else if (state is NegotiationLoaded)
                ..._buildOffersContent(state.offers)
              else if (state is NegotiationActionInProgress)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20)),
                          child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        ),
                        const SizedBox(height: 20),
                        const Text('Processing...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              else
                SliverFillRemaining(child: _buildEmptyState()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(
      icon: Icons.hourglass_empty_rounded,
      title: 'Waiting for offers...',
      subtitle: 'Providers in your area will send their fare offers soon.',
      iconGradient: AppTheme.accentGradient,
    );
  }

  List<Widget> _buildOffersContent(List<FareOfferEntity> offers) {
    final sortedOffers = List<FareOfferEntity>.from(offers);
    sortedOffers.sort((a, b) {
      if (a.status == FareOfferStatus.pending && b.status != FareOfferStatus.pending) return -1;
      if (a.status != FareOfferStatus.pending && b.status == FareOfferStatus.pending) return 1;
      return a.offeredPrice.compareTo(b.offeredPrice);
    });
    final activeOffers = sortedOffers.where((o) => o.status == FareOfferStatus.pending).length;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppTheme.secondaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text('$activeOffers Active', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('${sortedOffers.length} total offers', style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildOfferCard(sortedOffers[index])),
            childCount: sortedOffers.length,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
    ];
  }

  Widget _buildOfferCard(FareOfferEntity offer) {
    final isActive = offer.status == FareOfferStatus.pending || offer.status == FareOfferStatus.counterOffered;
    final priceDiff = offer.offeredPrice - widget.estimatedPrice;
    final pricePercent = (priceDiff / widget.estimatedPrice * 100).abs();

    Color priceColor;
    String priceLabel;
    IconData priceIcon;
    if (priceDiff < 0) {
      priceColor = AppTheme.successColor;
      priceLabel = '${pricePercent.toStringAsFixed(0)}% less';
      priceIcon = Icons.trending_down_rounded;
    } else if (priceDiff > 0) {
      priceColor = Colors.orange;
      priceLabel = '${pricePercent.toStringAsFixed(0)}% more';
      priceIcon = Icons.trending_up_rounded;
    } else {
      priceColor = AppTheme.primaryColor;
      priceLabel = 'Same as estimate';
      priceIcon = Icons.horizontal_rule_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive ? AppTheme.softShadow : [],
        border: isActive ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2) : Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isActive ? AppTheme.primaryGradient : null,
                    color: isActive ? null : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.person_rounded, color: isActive ? Colors.white : Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer.providerName ?? 'Service Provider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isActive ? AppTheme.textPrimary : Colors.grey)),
                      if (offer.estimatedArrivalMinutes != null)
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: isActive ? AppTheme.secondaryColor : Colors.grey),
                            const SizedBox(width: 4),
                            Text('Arrives in ${offer.estimatedArrivalMinutes} mins', style: TextStyle(color: isActive ? AppTheme.textSecondary : Colors.grey, fontSize: 13)),
                          ],
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isActive ? AppTheme.primaryGradient : null,
                        color: isActive ? null : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Rs. ${offer.offeredPrice.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isActive ? Colors.white : Colors.grey)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(priceIcon, size: 14, color: priceColor),
                        const SizedBox(width: 2),
                        Text(priceLabel, style: TextStyle(color: priceColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (offer.status == FareOfferStatus.counterOffered && offer.counterPrice != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text('You counter-offered: Rs. ${offer.counterPrice!.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            if (offer.message != null && offer.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote_rounded, color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(offer.message!, style: const TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSecondary))),
                  ],
                ),
              ),
            ],
            if (!isActive) ...[
              const SizedBox(height: 12),
              _buildStatusBadge(offer.status),
            ],
            if (isActive) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCounterOfferDialog(offer),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Counter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: AppTheme.errorColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: IconButton(onPressed: () => _rejectOffer(offer), icon: const Icon(Icons.close_rounded), color: AppTheme.errorColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.secondaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppTheme.successColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptOffer(offer),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Accept'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(FareOfferStatus status) {
    Color color;
    String label;
    IconData icon;
    LinearGradient? gradient;
    switch (status) {
      case FareOfferStatus.accepted:
        color = AppTheme.successColor;
        label = 'Accepted';
        icon = Icons.check_circle_rounded;
        gradient = AppTheme.secondaryGradient;
        break;
      case FareOfferStatus.rejected:
        color = AppTheme.errorColor;
        label = 'Rejected';
        icon = Icons.cancel_rounded;
        break;
      case FareOfferStatus.expired:
        color = Colors.grey;
        label = 'Expired';
        icon = Icons.access_time_rounded;
        break;
      case FareOfferStatus.withdrawn:
        color = Colors.orange;
        label = 'Withdrawn';
        icon = Icons.undo_rounded;
        break;
      default:
        color = Colors.grey;
        label = status.name;
        icon = Icons.info_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(gradient: gradient, color: gradient == null ? color.withOpacity(0.1) : null, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: gradient != null ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: gradient != null ? Colors.white : color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _acceptOffer(FareOfferEntity offer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: AppTheme.secondaryGradient, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.check_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('Accept Offer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Price: ', style: TextStyle(fontSize: 16)),
                  Text('Rs. ${offer.offeredPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('The provider will be notified and start heading to your location.', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          GradientButton(
            text: 'Accept',
            icon: Icons.check_rounded,
            gradient: AppTheme.secondaryGradient,
            onPressed: () {
              Navigator.pop(context);
              context.read<NegotiationBloc>().add(AcceptOfferRequested(offer.id));
            },
          ),
        ],
      ),
    );
  }

  void _rejectOffer(FareOfferEntity offer) {
    context.read<NegotiationBloc>().add(RejectOfferRequested(offer.id));
  }

  void _showCounterOfferDialog(FareOfferEntity offer) {
    final controller = TextEditingController(text: widget.estimatedPrice.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('Counter Offer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [const Text('Provider offered:'), Text('Rs. ${offer.offeredPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold))],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [const Text('Your estimate:'), Text('Rs. ${widget.estimatedPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor))],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Your counter price',
                prefixText: 'Rs. ',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          GradientButton(
            text: 'Send Counter',
            icon: Icons.send_rounded,
            gradient: AppTheme.accentGradient,
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null && price > 0) {
                Navigator.pop(context);
                context.read<NegotiationBloc>().add(CounterOfferRequested(offerId: offer.id, counterPrice: price));
              }
            },
          ),
        ],
      ),
    );
  }
}

class OffersPatternPainter extends CustomPainter {
  final Color color;
  OffersPatternPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    for (double i = 0; i < size.width; i += 30) {
      for (double j = 0; j < size.height; j += 30) {
        canvas.drawCircle(Offset(i, j), 2, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
