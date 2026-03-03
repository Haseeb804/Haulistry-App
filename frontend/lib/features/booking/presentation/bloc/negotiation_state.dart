import 'package:equatable/equatable.dart';
import '../../../../core/domain/entities/fare_offer_entity.dart';
import '../../../../core/domain/entities/booking_entity.dart';

/// Negotiation States
abstract class NegotiationState extends Equatable {
  const NegotiationState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class NegotiationInitial extends NegotiationState {
  const NegotiationInitial();
}

/// Loading offers
class NegotiationLoading extends NegotiationState {
  const NegotiationLoading();
}

/// Offers loaded successfully
class NegotiationLoaded extends NegotiationState {
  final String bookingId;
  final List<FareOfferEntity> offers;
  final FareOfferEntity? selectedOffer;

  const NegotiationLoaded({
    required this.bookingId,
    required this.offers,
    this.selectedOffer,
  });

  @override
  List<Object?> get props => [bookingId, offers, selectedOffer];

  NegotiationLoaded copyWith({
    String? bookingId,
    List<FareOfferEntity>? offers,
    FareOfferEntity? selectedOffer,
  }) {
    return NegotiationLoaded(
      bookingId: bookingId ?? this.bookingId,
      offers: offers ?? this.offers,
      selectedOffer: selectedOffer ?? this.selectedOffer,
    );
  }
}

/// Offer action in progress (accept, reject, counter)
class NegotiationActionInProgress extends NegotiationState {
  final String offerId;
  final String action; // 'accepting', 'rejecting', 'countering', etc.

  const NegotiationActionInProgress({
    required this.offerId,
    required this.action,
  });

  @override
  List<Object?> get props => [offerId, action];
}

/// Offer accepted - booking confirmed
class NegotiationOfferAccepted extends NegotiationState {
  final FareOfferEntity acceptedOffer;
  final BookingEntity? updatedBooking;

  const NegotiationOfferAccepted({
    required this.acceptedOffer,
    this.updatedBooking,
  });

  @override
  List<Object?> get props => [acceptedOffer, updatedBooking];
}

/// Counter offer sent successfully
class NegotiationCounterSent extends NegotiationState {
  final String offerId;
  final double counterPrice;

  const NegotiationCounterSent({
    required this.offerId,
    required this.counterPrice,
  });

  @override
  List<Object?> get props => [offerId, counterPrice];
}

/// Provider's offer created successfully
class NegotiationOfferCreated extends NegotiationState {
  final FareOfferEntity offer;

  const NegotiationOfferCreated(this.offer);

  @override
  List<Object?> get props => [offer];
}

/// Error state
class NegotiationError extends NegotiationState {
  final String message;

  const NegotiationError(this.message);

  @override
  List<Object?> get props => [message];
}
