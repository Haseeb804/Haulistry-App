import 'package:equatable/equatable.dart';
import '../../../../core/domain/entities/fare_offer_entity.dart';

/// Negotiation Events
abstract class NegotiationEvent extends Equatable {
  const NegotiationEvent();

  @override
  List<Object?> get props => [];
}

/// Load offers for a booking (seeker views all bids)
class LoadBookingOffersRequested extends NegotiationEvent {
  final String bookingId;

  const LoadBookingOffersRequested(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

/// Provider creates a new offer
class CreateOfferRequested extends NegotiationEvent {
  final String bookingId;
  final String providerId;
  final String vehicleId;
  final double offeredPrice;
  final String? message;
  final int? estimatedArrivalMinutes;

  const CreateOfferRequested({
    required this.bookingId,
    required this.providerId,
    required this.vehicleId,
    required this.offeredPrice,
    this.message,
    this.estimatedArrivalMinutes,
  });

  @override
  List<Object?> get props =>
      [bookingId, providerId, vehicleId, offeredPrice, message, estimatedArrivalMinutes];
}

/// Seeker accepts an offer
class AcceptOfferRequested extends NegotiationEvent {
  final String offerId;

  const AcceptOfferRequested(this.offerId);

  @override
  List<Object?> get props => [offerId];
}

/// Seeker rejects an offer
class RejectOfferRequested extends NegotiationEvent {
  final String offerId;

  const RejectOfferRequested(this.offerId);

  @override
  List<Object?> get props => [offerId];
}

/// Seeker makes a counter offer
class CounterOfferRequested extends NegotiationEvent {
  final String offerId;
  final double counterPrice;

  const CounterOfferRequested({
    required this.offerId,
    required this.counterPrice,
  });

  @override
  List<Object?> get props => [offerId, counterPrice];
}

/// Provider updates their offer price
class UpdateOfferPriceRequested extends NegotiationEvent {
  final String offerId;
  final double newPrice;
  final String? message;

  const UpdateOfferPriceRequested({
    required this.offerId,
    required this.newPrice,
    this.message,
  });

  @override
  List<Object?> get props => [offerId, newPrice, message];
}

/// Provider withdraws their offer
class WithdrawOfferRequested extends NegotiationEvent {
  final String offerId;

  const WithdrawOfferRequested(this.offerId);

  @override
  List<Object?> get props => [offerId];
}

/// New offer received via FCM
class NewOfferReceived extends NegotiationEvent {
  final FareOfferEntity offer;

  const NewOfferReceived(this.offer);

  @override
  List<Object?> get props => [offer];
}

/// Offer status updated via FCM
class OfferStatusUpdated extends NegotiationEvent {
  final String offerId;
  final String status;
  final double? newPrice;

  const OfferStatusUpdated({
    required this.offerId,
    required this.status,
    this.newPrice,
  });

  @override
  List<Object?> get props => [offerId, status, newPrice];
}

/// Reset negotiation state
class NegotiationReset extends NegotiationEvent {
  const NegotiationReset();
}
