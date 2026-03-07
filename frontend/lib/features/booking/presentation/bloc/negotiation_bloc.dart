import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'negotiation_event.dart';
import 'negotiation_state.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/domain/entities/fare_offer_entity.dart';
import '../../../../core/domain/entities/booking_entity.dart';

/// NegotiationBloc - Handles InDrive-style fare negotiation
/// Manages offers, counter-offers, and acceptance flow
class NegotiationBloc extends Bloc<NegotiationEvent, NegotiationState> {
  final ApiService _apiService;
  final NotificationService _notificationService;
  StreamSubscription<Map<String, dynamic>>? _fcmSubscription;

  NegotiationBloc({
    ApiService? apiService,
    NotificationService? notificationService,
  })  : _apiService = apiService ?? ApiService.instance,
        _notificationService = notificationService ?? NotificationService(),
        super(const NegotiationInitial()) {
    // Register event handlers
    on<LoadBookingOffersRequested>(_onLoadOffers);
    on<CreateOfferRequested>(_onCreateOffer);
    on<AcceptOfferRequested>(_onAcceptOffer);
    on<RejectOfferRequested>(_onRejectOffer);
    on<CounterOfferRequested>(_onCounterOffer);
    on<UpdateOfferPriceRequested>(_onUpdateOfferPrice);
    on<WithdrawOfferRequested>(_onWithdrawOffer);
    on<NewOfferReceived>(_onNewOfferReceived);
    on<OfferStatusUpdated>(_onOfferStatusUpdated);
    on<NegotiationReset>(_onReset);

    // Listen to FCM notification stream for fare offers
    _fcmSubscription = _notificationService.notificationStream.listen(_handleFcmMessage);
  }

  void _handleFcmMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'new_fare_offer':
        final offer = FareOfferEntity.fromJson(data);
        add(NewOfferReceived(offer));
        break;

      case 'fare_offer_accepted':
        _handleOfferStatusUpdate(data, 'accepted');
        break;

      case 'fare_offer_rejected':
        _handleOfferStatusUpdate(data, 'rejected');
        break;

      case 'offer_updated':
        _handleOfferStatusUpdate(data, 'updated');
        break;

      case 'offer_withdrawn':
        _handleOfferStatusUpdate(data, 'withdrawn');
        break;

      case 'counter_offer':
        final offerId = data['offerId'] as String?;
        final counterPrice = double.tryParse(data['counterPrice']?.toString() ?? '');
        if (offerId != null && counterPrice != null) {
          add(OfferStatusUpdated(
            offerId: offerId,
            status: 'counter_offered',
            newPrice: counterPrice,
          ));
        }
        break;

      default:
        break;
    }
  }

  void _handleOfferStatusUpdate(Map<String, dynamic> data, String status) {
    final offerId = data['id'] as String? ?? data['offerId'] as String?;
    if (offerId != null) {
      add(OfferStatusUpdated(
        offerId: offerId,
        status: status,
        newPrice: double.tryParse(data['offeredPrice']?.toString() ?? ''),
      ));
    }
  }

  /// Load all offers for a booking
  Future<void> _onLoadOffers(
    LoadBookingOffersRequested event,
    Emitter<NegotiationState> emit,
  ) async {
    emit(const NegotiationLoading());

    try {
      final response = await _apiService.getBookingOffers(event.bookingId);

      if (response['success'] == true) {
        final offersJson = response['offers'] as List<dynamic>? ?? [];
        final offers = offersJson
            .map((json) => FareOfferEntity.fromJson(json as Map<String, dynamic>))
            .toList();

        emit(NegotiationLoaded(
          bookingId: event.bookingId,
          offers: offers,
        ));
      } else {
        emit(NegotiationError(response['message'] ?? 'Failed to load offers'));
      }
    } catch (e) {
      emit(NegotiationError('Error loading offers: $e'));
    }
  }

  /// Provider creates a new fare offer
  Future<void> _onCreateOffer(
    CreateOfferRequested event,
    Emitter<NegotiationState> emit,
  ) async {
    emit(NegotiationActionInProgress(
      offerId: '',
      action: 'creating',
    ));

    try {
      final response = await _apiService.createFareOffer({
        'bookingId': event.bookingId,
        'providerId': event.providerId,
        'vehicleId': event.vehicleId,
        'offeredPrice': event.offeredPrice,
        'message': event.message,
        'estimatedArrivalMinutes': event.estimatedArrivalMinutes,
      });

      if (response['success'] == true) {
        final offer = FareOfferEntity.fromJson(
          response['offer'] as Map<String, dynamic>,
        );
        emit(NegotiationOfferCreated(offer));
      } else {
        emit(NegotiationError(response['message'] ?? 'Failed to create offer'));
      }
    } catch (e) {
      emit(NegotiationError('Error creating offer: $e'));
    }
  }

  /// Seeker accepts an offer
  Future<void> _onAcceptOffer(
    AcceptOfferRequested event,
    Emitter<NegotiationState> emit,
  ) async {
    emit(NegotiationActionInProgress(
      offerId: event.offerId,
      action: 'accepting',
    ));

    try {
      final response = await _apiService.acceptFareOffer(event.offerId);

      if (response['success'] == true) {
        final offerData = response['offer'] as Map<String, dynamic>;
        final offer = FareOfferEntity.fromJson(offerData);

        BookingEntity? booking;
        if (offerData['booking'] != null) {
          booking = BookingEntity.fromJson(
            offerData['booking'] as Map<String, dynamic>,
          );
        }

        emit(NegotiationOfferAccepted(
          acceptedOffer: offer,
          updatedBooking: booking,
        ));
      } else {
        emit(NegotiationError(response['message'] ?? 'Failed to accept offer'));
      }
    } catch (e) {
      emit(NegotiationError('Error accepting offer: $e'));
    }
  }

  /// Seeker rejects an offer
  Future<void> _onRejectOffer(
    RejectOfferRequested event,
    Emitter<NegotiationState> emit,
  ) async {
    final currentState = state;

    emit(NegotiationActionInProgress(
      offerId: event.offerId,
      action: 'rejecting',
    ));

    try {
      final response = await _apiService.rejectFareOffer(event.offerId);

      if (response['success'] == true) {
        // Update offers list if we have current state
        if (currentState is NegotiationLoaded) {
          final updatedOffers = currentState.offers
              .map((o) => o.id == event.offerId
                  ? o.copyWith(status: FareOfferStatus.rejected)
                  : o)
              .toList();

          emit(currentState.copyWith(offers: updatedOffers));
        } else {
          emit(const NegotiationInitial());
        }
      } else {
        emit(NegotiationError(response['message'] ?? 'Failed to reject offer'));
      }
    } catch (e) {
      emit(NegotiationError('Error rejecting offer: $e'));
    }
  }

  /// Seeker sends a counter offer
  Future<void> _onCounterOffer(
    CounterOfferRequested event,
    Emitter<NegotiationState> emit,
  ) async {
    emit(NegotiationActionInProgress(
      offerId: event.offerId,
      action: 'countering',
    ));

    try {
      final response = await _apiService.counterOffer(
        event.offerId,
        event.counterPrice,
      );

      if (response['success'] == true) {
        emit(NegotiationCounterSent(
          offerId: event.offerId,
          counterPrice: event.counterPrice,
        ));
      } else {
        emit(NegotiationError(response['message'] ?? 'Failed to send counter offer'));
      }
    } catch (e) {
      emit(NegotiationError('Error sending counter offer: $e'));
    }
  }

  /// Provider updates their offer price
  Future<void> _onUpdateOfferPrice(
    UpdateOfferPriceRequested event,
    Emitter<NegotiationState> emit,
  ) async {
    emit(NegotiationActionInProgress(
      offerId: event.offerId,
      action: 'updating',
    ));

    try {
      final response = await _apiService.updateOfferPrice(
        event.offerId,
        event.newPrice,
        message: event.message,
      );

      if (response['success'] == true) {
        final offer = FareOfferEntity.fromJson(
          response['offer'] as Map<String, dynamic>,
        );
        emit(NegotiationOfferCreated(offer));
      } else {
        emit(NegotiationError(response['message'] ?? 'Failed to update offer'));
      }
    } catch (e) {
      emit(NegotiationError('Error updating offer: $e'));
    }
  }

  /// Provider withdraws their offer
  Future<void> _onWithdrawOffer(
    WithdrawOfferRequested event,
    Emitter<NegotiationState> emit,
  ) async {
    emit(NegotiationActionInProgress(
      offerId: event.offerId,
      action: 'withdrawing',
    ));

    try {
      final response = await _apiService.withdrawOffer(event.offerId);

      if (response['success'] == true) {
        emit(const NegotiationInitial());
      } else {
        emit(NegotiationError(response['message'] ?? 'Failed to withdraw offer'));
      }
    } catch (e) {
      emit(NegotiationError('Error withdrawing offer: $e'));
    }
  }

  /// Handle new offer from WebSocket
  void _onNewOfferReceived(
    NewOfferReceived event,
    Emitter<NegotiationState> emit,
  ) {
    final currentState = state;

    if (currentState is NegotiationLoaded &&
        currentState.bookingId == event.offer.bookingId) {
      // Add new offer to the list
      final updatedOffers = [event.offer, ...currentState.offers];
      emit(currentState.copyWith(offers: updatedOffers));
    }
  }

  /// Handle offer status update from WebSocket
  void _onOfferStatusUpdated(
    OfferStatusUpdated event,
    Emitter<NegotiationState> emit,
  ) {
    final currentState = state;

    if (currentState is NegotiationLoaded) {
      final updatedOffers = currentState.offers.map((offer) {
        if (offer.id == event.offerId) {
          FareOfferStatus newStatus;
          switch (event.status) {
            case 'accepted':
              newStatus = FareOfferStatus.accepted;
              break;
            case 'rejected':
              newStatus = FareOfferStatus.rejected;
              break;
            case 'counter_offered':
              newStatus = FareOfferStatus.counterOffered;
              break;
            case 'withdrawn':
              newStatus = FareOfferStatus.withdrawn;
              break;
            default:
              newStatus = offer.status;
          }

          return offer.copyWith(
            status: newStatus,
            counterPrice: event.newPrice ?? offer.counterPrice,
          );
        }
        return offer;
      }).toList();

      emit(currentState.copyWith(offers: updatedOffers));
    }
  }

  /// Reset state
  void _onReset(
    NegotiationReset event,
    Emitter<NegotiationState> emit,
  ) {
    emit(const NegotiationInitial());
  }

  @override
  Future<void> close() {
    _fcmSubscription?.cancel();
    return super.close();
  }
}
