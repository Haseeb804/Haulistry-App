import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'provider_event.dart';
import 'provider_state.dart';
import '../../domain/repositories/provider_repository.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/domain/entities/vehicle_entity.dart';
import '../../../../core/domain/entities/fare_offer_entity.dart';
import '../../../../core/domain/entities/service_entity.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/websocket_service.dart';

class ProviderBloc extends Bloc<ProviderEvent, ProviderState> {
  final ProviderRepository _repository;
  final FirebaseAuth _auth;
  final ApiService _apiService;
  final WebSocketService _wsService;

  StreamSubscription? _bookingRequestSubscription;
  StreamSubscription? _fareOfferSubscription;
  bool _isOnline = false;

  ProviderBloc({
    required ProviderRepository repository,
    FirebaseAuth? auth,
    ApiService? apiService,
    WebSocketService? wsService,
  })  : _repository = repository,
        _auth = auth ?? FirebaseAuth.instance,
        _apiService = apiService ?? ApiService.instance,
        _wsService = wsService ?? WebSocketService.instance,
        super(const ProviderInitial()) {
    // Dashboard & Booking Events
    on<ProviderLoadDashboardRequested>(_onLoadDashboard);
    on<ProviderLoadBookingsRequested>(_onLoadBookingsRequested);
    on<ProviderLoadAvailableBookingsRequested>(_onLoadAvailableBookings);
    on<ProviderAcceptBookingRequested>(_onAcceptBookingRequested);
    on<ProviderRejectBookingRequested>(_onRejectBookingRequested);
    on<ProviderStartBookingRequested>(_onStartBookingRequested);
    on<ProviderCompleteBookingRequested>(_onCompleteBookingRequested);
    on<ProviderCancelBookingRequested>(_onCancelBookingRequested);
    
    // Vehicle Events
    on<ProviderLoadVehiclesRequested>(_onLoadVehiclesRequested);
    on<ProviderAddVehicleRequested>(_onAddVehicleRequested);
    on<ProviderUpdateVehicleRequested>(_onUpdateVehicleRequested);
    on<ProviderDeleteVehicleRequested>(_onDeleteVehicleRequested);
    on<ProviderToggleVehicleAvailability>(_onToggleVehicleAvailability);
    
    // Service Events
    on<ProviderLoadServicesRequested>(_onLoadServicesRequested);
    on<ProviderLoadVehicleServicesRequested>(_onLoadVehicleServicesRequested);
    on<ProviderAddServiceRequested>(_onAddServiceRequested);
    on<ProviderUpdateServiceRequested>(_onUpdateServiceRequested);
    on<ProviderDeleteServiceRequested>(_onDeleteServiceRequested);
    
    // Earnings Events
    on<ProviderLoadEarningsRequested>(_onLoadEarningsRequested);
    on<ProviderRequestWithdrawal>(_onRequestWithdrawal);
    
    // Fare Offer Events (InDrive-style)
    on<ProviderCreateFareOfferRequested>(_onCreateFareOffer);
    on<ProviderUpdateOfferPriceRequested>(_onUpdateOfferPrice);
    on<ProviderWithdrawOfferRequested>(_onWithdrawOffer);
    on<ProviderLoadOffersRequested>(_onLoadOffers);
    
    // WebSocket Events
    on<ProviderNewBookingReceived>(_onNewBookingReceived);
    on<ProviderOfferStatusReceived>(_onOfferStatusReceived);
    
    // Online Status Events
    on<ProviderGoOnline>(_onGoOnline);
    on<ProviderGoOffline>(_onGoOffline);
    on<ProviderUpdateLocation>(_onUpdateLocation);

    // Setup WebSocket listeners
    _setupWebSocketListeners();
  }

  void _setupWebSocketListeners() {
    // Listen for new booking requests
    _bookingRequestSubscription = _wsService.bookingRequestStream.listen((message) {
      if (message.data.isNotEmpty) {
        add(ProviderNewBookingReceived(
          booking: BookingEntity.fromJson(message.data),
        ));
      }
    });

    // Listen for fare offer updates (counter offers, acceptance, etc.)
    _fareOfferSubscription = _wsService.fareOfferStream.listen((message) {
      final offerId = message.data['id'] as String? ?? message.data['offerId'] as String?;
      if (offerId != null) {
        String status = 'unknown';
        if (message.type == WSMessageType.fareOfferAccepted) {
          status = 'accepted';
        } else if (message.type == WSMessageType.fareOfferRejected) {
          status = 'rejected';
        } else if (message.type == WSMessageType.counterOffer) {
          status = 'counter_offered';
        }
        
        add(ProviderOfferStatusReceived(
          offerId: offerId,
          status: status,
          counterPrice: (message.data['counterPrice'] as num?)?.toDouble(),
        ));
      }
    });
  }

  Future<void> _onLoadDashboard(
    ProviderLoadDashboardRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(const ProviderLoading());

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Fetch all data in parallel with individual error handling
      List<BookingEntity> allBookings = [];
      List<VehicleEntity> vehicles = [];
      List<BookingEntity> availableBookings = [];
      List<FareOfferEntity> pendingOffers = [];

      await Future.wait([
        _repository.getProviderBookings(user.uid)
            .timeout(const Duration(seconds: 10))
            .then((result) {
          allBookings = result;
        }).catchError((e) {
          allBookings = [];
        }),
        _repository.getProviderVehicles(user.uid)
            .timeout(const Duration(seconds: 10))
            .then((result) {
          vehicles = result;
        }).catchError((e) {
          vehicles = [];
        }),
        _apiService.getAvailableBookings()
            .timeout(const Duration(seconds: 10))
            .then((response) {
          availableBookings = (response['bookings'] as List<dynamic>? ?? [])
              .map((json) => BookingEntity.fromJson(json as Map<String, dynamic>))
              .toList();
        }).catchError((e) {
          availableBookings = [];
        }),
        _apiService.getProviderOffers(user.uid, status: 'pending')
            .timeout(const Duration(seconds: 10))
            .then((response) {
          pendingOffers = (response['offers'] as List<dynamic>? ?? [])
              .map((json) => FareOfferEntity.fromJson(json as Map<String, dynamic>))
              .toList();
        }).catchError((e) {
          pendingOffers = [];
        }),
      ]);

      // Categorize bookings - case-insensitive status checks
      final pendingBookings = allBookings.where((b) => 
          b.status.toLowerCase() == 'pending').toList();
      final activeBookings = allBookings
          .where((b) => ['accepted', 'provider_arriving', 'provider_arrived', 'in_progress']
              .contains(b.status.toLowerCase()))
          .toList();
      final completedBookings = allBookings.where((b) => 
          b.status.toLowerCase() == 'completed').toList();

      // Calculate earnings
      final totalEarnings = completedBookings.fold<double>(
        0,
        (sum, booking) => sum + (booking.finalPrice ?? booking.estimatedPrice),
      );
      final pendingEarnings = activeBookings.fold<double>(
        0,
        (sum, booking) => sum + booking.estimatedPrice,
      );

      emit(ProviderLoaded(
        pendingBookings: pendingBookings,
        activeBookings: activeBookings,
        completedBookings: completedBookings,
        availableBookings: availableBookings,
        pendingOffers: pendingOffers,
        vehicles: vehicles,
        totalEarnings: totalEarnings,
        pendingEarnings: pendingEarnings,
        isOnline: _isOnline,
      ));
    } catch (e) {
      emit(ProviderError(message: 'Error loading dashboard: ${e.toString()}'));
    }
  }

  Future<void> _onAcceptBookingRequested(
    ProviderAcceptBookingRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(ProviderBookingActionInProgress(
      bookingId: event.bookingId,
      action: 'accepting',
    ));

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Accept booking via backend
      await _repository.acceptBooking(event.bookingId, user.uid);

      emit(const ProviderBookingActionSuccess(
        message: 'Booking accepted successfully',
      ));

      // Reload bookings
      add(const ProviderLoadBookingsRequested());
    } catch (e) {
      emit(ProviderError(message: 'Error accepting booking: ${e.toString()}'));
    }
  }

  Future<void> _onRejectBookingRequested(
    ProviderRejectBookingRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(ProviderBookingActionInProgress(
      bookingId: event.bookingId,
      action: 'rejecting',
    ));

    try {
      final user = _auth.currentUser;
      if (user == null) {
        emit(const ProviderError(message: 'User not authenticated'));
        return;
      }

      // Reject booking via backend with provider_id and reason
      await _repository.rejectBooking(event.bookingId, user.uid, reason: event.reason);

      emit(const ProviderBookingActionSuccess(
        message: 'Booking rejected',
      ));

      // Reload bookings
      add(const ProviderLoadBookingsRequested());
    } catch (e) {
      emit(ProviderError(message: 'Error rejecting booking: ${e.toString()}'));
    }
  }

  Future<void> _onStartBookingRequested(
    ProviderStartBookingRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(ProviderBookingActionInProgress(
      bookingId: event.bookingId,
      action: 'starting',
    ));

    try {
      // TODO: Implement actual API call to start booking
      await Future.delayed(const Duration(seconds: 1));

      emit(const ProviderBookingActionSuccess(
        message: 'Booking started',
      ));

      // Reload bookings
      add(const ProviderLoadBookingsRequested());
    } catch (e) {
      emit(ProviderError(message: 'Error starting booking: ${e.toString()}'));
    }
  }

  Future<void> _onCompleteBookingRequested(
    ProviderCompleteBookingRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(ProviderBookingActionInProgress(
      bookingId: event.bookingId,
      action: 'completing',
    ));

    try {
      // Call the repository to complete the booking
      await _repository.completeBooking(event.bookingId);

      emit(const ProviderBookingActionSuccess(
        message: 'Booking completed successfully',
      ));

      // Reload bookings
      add(const ProviderLoadBookingsRequested());
    } catch (e) {
      emit(ProviderError(message: 'Error completing booking: ${e.toString()}'));
    }
  }

  Future<void> _onCancelBookingRequested(
    ProviderCancelBookingRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(ProviderBookingActionInProgress(
      bookingId: event.bookingId,
      action: 'cancelling',
    ));

    try {
      // TODO: Implement actual API call to cancel booking
      await Future.delayed(const Duration(seconds: 1));

      emit(const ProviderBookingActionSuccess(
        message: 'Booking cancelled',
      ));

      // Reload bookings
      add(const ProviderLoadBookingsRequested());
    } catch (e) {
      emit(ProviderError(message: 'Error cancelling booking: ${e.toString()}'));
    }
  }

  Future<void> _onLoadVehiclesRequested(
    ProviderLoadVehiclesRequested event,
    Emitter<ProviderState> emit,
  ) async {
    // Don't emit loading to avoid replacing current state
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final vehicles = await _repository.getProviderVehicles(user.uid);
      
      // Update current state with vehicles if it's ProviderLoaded
      final currentState = state;
      if (currentState is ProviderLoaded) {
        emit(currentState.copyWith(vehicles: vehicles));
      } else {
        // Trigger full dashboard load
        add(const ProviderLoadDashboardRequested());
      }
    } catch (e) {
      // Don't emit error state, just log it
    }
  }

  Future<void> _onAddVehicleRequested(
    ProviderAddVehicleRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(const ProviderVehicleActionInProgress());

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _repository.createVehicle(
        providerId: user.uid,
        vehicleType: event.vehicleType,
        vehicleModel: event.vehicleModel,
        vehicleYear: event.vehicleYear,
        licensePlate: event.licensePlate,
        capacity: event.capacity,
        pricePerHour: event.pricePerHour,
        pricePerKm: event.pricePerKm,
        imageUrls: event.imageUrls,
        vehicleImageBase64: event.vehicleImageBase64,
      );

      emit(const ProviderVehicleActionSuccess(
        message: 'Vehicle added successfully',
      ));

      // Reload data
      add(const ProviderLoadBookingsRequested());
    } catch (e) {
      emit(ProviderError(message: 'Error adding vehicle: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateVehicleRequested(
    ProviderUpdateVehicleRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(const ProviderVehicleActionInProgress());

    try {
      await _repository.updateVehicle(event.vehicleId, event.updates);

      emit(const ProviderVehicleActionSuccess(
        message: 'Vehicle updated successfully',
      ));

      // Reload data
      add(const ProviderLoadBookingsRequested());
    } catch (e) {
      emit(ProviderError(message: 'Error updating vehicle: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteVehicleRequested(
    ProviderDeleteVehicleRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(const ProviderVehicleActionInProgress());

    try {
      await _repository.deleteVehicle(event.vehicleId);

      emit(const ProviderVehicleActionSuccess(
        message: 'Vehicle deleted successfully',
      ));

      // Reload data
      add(const ProviderLoadBookingsRequested());
    } catch (e) {
      emit(ProviderError(message: 'Error deleting vehicle: ${e.toString()}'));
    }
  }

  Future<void> _onToggleVehicleAvailability(
    ProviderToggleVehicleAvailability event,
    Emitter<ProviderState> emit,
  ) async {
    try {
      await _repository.updateVehicle(
        event.vehicleId,
        {'isAvailable': event.isAvailable},
      );

      // Reload data
      add(const ProviderLoadBookingsRequested());
    } catch (e) {
      emit(ProviderError(
          message: 'Error toggling vehicle availability: ${e.toString()}'));
    }
  }

  // ===== Service Handlers =====

  Future<void> _onLoadServicesRequested(
    ProviderLoadServicesRequested event,
    Emitter<ProviderState> emit,
  ) async {
    // Only show loading if not already in ProviderLoaded state
    final currentState = state;
    if (currentState is! ProviderLoaded) {
      emit(const ProviderLoading());
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Load both services and vehicles in parallel
      final results = await Future.wait([
        _repository.getProviderServices(user.uid).catchError((e) {
          return <ServiceEntity>[];
        }),
        _repository.getProviderVehicles(user.uid).catchError((e) {
          return <VehicleEntity>[];
        }),
      ]);

      final services = results[0] as List<ServiceEntity>;
      final vehicles = results[1] as List<VehicleEntity>;

      // If we have existing ProviderLoaded state, preserve other data
      if (currentState is ProviderLoaded) {
        emit(currentState.copyWith(
          services: services,
          vehicles: vehicles,
        ));
      } else {
        emit(ProviderLoaded(
          pendingBookings: [],
          activeBookings: [],
          completedBookings: [],
          vehicles: vehicles,
          services: services,
          totalEarnings: 0,
          pendingEarnings: 0,
          isOnline: _isOnline,
        ));
      }
    } catch (e) {
      emit(ProviderError(message: 'Error loading services: ${e.toString()}'));
    }
  }

  Future<void> _onLoadVehicleServicesRequested(
    ProviderLoadVehicleServicesRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(const ProviderLoading());

    try {
      final services = await _repository.getVehicleServices(event.vehicleId);
      emit(ProviderServicesLoaded(services: services));
    } catch (e) {
      emit(ProviderError(message: 'Error loading vehicle services: ${e.toString()}'));
    }
  }

  Future<void> _onAddServiceRequested(
    ProviderAddServiceRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(const ProviderServiceActionInProgress());

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _repository.createService(
        providerId: user.uid,
        vehicleId: event.vehicleId,
        name: event.name,
        description: event.description,
        imageUrl: event.imageUrl,
        basePrice: event.basePrice,
        pricePerKm: event.pricePerKm,
        pricePerHour: event.pricePerHour,
        category: event.category,
      );

      emit(const ProviderServiceActionSuccess(
        message: 'Service added successfully',
      ));

      // Reload services
      add(const ProviderLoadServicesRequested());
    } catch (e) {
      emit(ProviderError(message: 'Error adding service: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateServiceRequested(
    ProviderUpdateServiceRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(const ProviderServiceActionInProgress());

    try {
      await _repository.updateService(event.serviceId, event.updates);

      emit(const ProviderServiceActionSuccess(
        message: 'Service updated successfully',
      ));

      // Reload services
      add(const ProviderLoadServicesRequested());
    } catch (e) {
      emit(ProviderError(message: 'Error updating service: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteServiceRequested(
    ProviderDeleteServiceRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(const ProviderServiceActionInProgress());

    try {
      await _repository.deleteService(event.serviceId);

      emit(const ProviderServiceActionSuccess(
        message: 'Service deleted successfully',
      ));

      // Reload services
      add(const ProviderLoadServicesRequested());
    } catch (e) {
      emit(ProviderError(message: 'Error deleting service: ${e.toString()}'));
    }
  }

  Future<void> _onLoadEarningsRequested(
    ProviderLoadEarningsRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(const ProviderLoading());

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Fetch completed bookings from repository to calculate earnings
      List<BookingEntity> completed = [];
      try {
        final allBookings = await _repository.getProviderBookings(user.uid)
            .timeout(const Duration(seconds: 15));
        // Case-insensitive status check
        completed = allBookings.where((b) => 
            b.status.toLowerCase() == 'completed').toList();
      } catch (e) {
        // Continue with empty list if bookings fail to load
        completed = [];
      }

      // Calculate earnings from completed bookings
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      double totalEarnings = 0.0;
      double thisMonth = 0.0;
      double thisWeek = 0.0;
      double today = 0.0;
      
      final recentEarnings = <EarningEntry>[];

      for (final booking in completed) {
        final amount = booking.finalPrice ?? booking.estimatedPrice;
        totalEarnings += amount;

        final completedAt = booking.completedAt ?? booking.updatedAt ?? booking.createdAt;
        
        if (completedAt.isAfter(monthStart)) {
          thisMonth += amount;
        }
        if (completedAt.isAfter(weekStart)) {
          thisWeek += amount;
        }
        if (completedAt.isAfter(todayStart)) {
          today += amount;
        }

        // Add to recent earnings (limit to 10 most recent)
        if (recentEarnings.length < 10) {
          recentEarnings.add(EarningEntry(
            bookingId: booking.id,
            date: completedAt,
            amount: amount,
            serviceType: booking.serviceType,
            status: 'paid',
          ));
        }
      }

      emit(ProviderEarningsLoaded(
        totalEarnings: totalEarnings,
        thisMonth: thisMonth,
        thisWeek: thisWeek,
        today: today,
        recentEarnings: recentEarnings,
      ));
    } catch (e) {
      emit(ProviderError(message: 'Error loading earnings: ${e.toString()}'));
    }
  }

  Future<void> _onRequestWithdrawal(
    ProviderRequestWithdrawal event,
    Emitter<ProviderState> emit,
  ) async {
    emit(const ProviderWithdrawalInProgress());

    try {
      // TODO: Implement actual API call to request withdrawal when endpoint is available
      await Future.delayed(const Duration(seconds: 1));

      emit(ProviderWithdrawalSuccess(
        message: 'Withdrawal request submitted. Amount: Rs. ${event.amount.toStringAsFixed(0)}',
      ));

      // Reload earnings
      add(const ProviderLoadEarningsRequested());
    } catch (e) {
      emit(ProviderError(
          message: 'Error requesting withdrawal: ${e.toString()}'));
    }
  }

  // ===== Fare Offer Handlers (InDrive-style bidding) =====

  Future<void> _onCreateFareOffer(
    ProviderCreateFareOfferRequested event,
    Emitter<ProviderState> emit,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      emit(const ProviderError(message: 'User not authenticated'));
      return;
    }

    emit(ProviderOfferActionInProgress(offerId: '', action: 'creating'));

    try {
      final response = await _apiService.createFareOffer({
        'bookingId': event.bookingId,
        'providerId': user.uid,
        'vehicleId': event.vehicleId,
        'offeredPrice': event.offeredPrice,
        'message': event.message,
        'estimatedArrivalMinutes': event.estimatedArrivalMinutes,
      });

      if (response['success'] == true) {
        final offer = FareOfferEntity.fromJson(
          response['offer'] as Map<String, dynamic>,
        );
        emit(ProviderOfferCreatedSuccess(offer: offer));
        
        // Refresh dashboard
        add(const ProviderLoadDashboardRequested());
      } else {
        emit(ProviderError(message: response['message'] ?? 'Failed to create offer'));
      }
    } catch (e) {
      emit(ProviderError(message: 'Error creating offer: $e'));
    }
  }

  Future<void> _onUpdateOfferPrice(
    ProviderUpdateOfferPriceRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(ProviderOfferActionInProgress(offerId: event.offerId, action: 'updating'));

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
        emit(ProviderOfferUpdatedSuccess(
          offer: offer,
          message: 'Price updated to Rs. ${event.newPrice.toStringAsFixed(0)}',
        ));
      } else {
        emit(ProviderError(message: response['message'] ?? 'Failed to update offer'));
      }
    } catch (e) {
      emit(ProviderError(message: 'Error updating offer: $e'));
    }
  }

  Future<void> _onWithdrawOffer(
    ProviderWithdrawOfferRequested event,
    Emitter<ProviderState> emit,
  ) async {
    emit(ProviderOfferActionInProgress(offerId: event.offerId, action: 'withdrawing'));

    try {
      final response = await _apiService.withdrawOffer(event.offerId);

      if (response['success'] == true) {
        emit(const ProviderBookingActionSuccess(message: 'Offer withdrawn'));
        add(const ProviderLoadDashboardRequested());
      } else {
        emit(ProviderError(message: response['message'] ?? 'Failed to withdraw offer'));
      }
    } catch (e) {
      emit(ProviderError(message: 'Error withdrawing offer: $e'));
    }
  }

  Future<void> _onLoadOffers(
    ProviderLoadOffersRequested event,
    Emitter<ProviderState> emit,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      emit(const ProviderError(message: 'User not authenticated'));
      return;
    }

    try {
      final response = await _apiService.getProviderOffers(user.uid, status: event.status);

      if (response['success'] == true && state is ProviderLoaded) {
        final offers = (response['offers'] as List<dynamic>? ?? [])
            .map((json) => FareOfferEntity.fromJson(json as Map<String, dynamic>))
            .toList();

        emit((state as ProviderLoaded).copyWith(pendingOffers: offers));
      }
    } catch (e) {
      emit(ProviderError(message: 'Error loading offers: $e'));
    }
  }

  // ===== WebSocket Event Handlers =====

  void _onNewBookingReceived(
    ProviderNewBookingReceived event,
    Emitter<ProviderState> emit,
  ) {
    final currentState = state;

    if (currentState is ProviderLoaded) {
      // Add new booking to available bookings list
      emit(currentState.copyWith(
        availableBookings: [event.booking, ...currentState.availableBookings],
      ));
    }
  }

  void _onOfferStatusReceived(
    ProviderOfferStatusReceived event,
    Emitter<ProviderState> emit,
  ) {
    final currentState = state;

    if (event.status == 'accepted') {
      // Offer was accepted - reload dashboard to get updated booking
      add(const ProviderLoadDashboardRequested());
    } else if (event.status == 'counter_offered' && event.counterPrice != null) {
      // Seeker sent a counter offer
      if (currentState is ProviderLoaded) {
        final offer = currentState.pendingOffers.firstWhere(
          (o) => o.id == event.offerId,
          orElse: () => FareOfferEntity(
            id: event.offerId,
            bookingId: '',
            providerId: '',
            vehicleId: '',
            offeredPrice: 0,
            status: FareOfferStatus.pending,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        emit(ProviderCounterOfferReceived(
          offerId: event.offerId,
          counterPrice: event.counterPrice!,
          originalPrice: offer.offeredPrice,
        ));
      }
    } else if (event.status == 'rejected') {
      // Offer was rejected - refresh offers
      add(const ProviderLoadOffersRequested());
    }
  }

  // ===== Online Status Handlers =====

  Future<void> _onGoOnline(
    ProviderGoOnline event,
    Emitter<ProviderState> emit,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      emit(const ProviderError(message: 'User not authenticated'));
      return;
    }

    try {
      // Connect to WebSocket
      await _wsService.connect(user.uid, role: 'provider');

      // Subscribe to service categories
      for (final category in event.serviceCategories ?? ['general']) {
        _wsService.subscribeToCategory(category);
      }

      _isOnline = true;

      if (state is ProviderLoaded) {
        emit((state as ProviderLoaded).copyWith(isOnline: true));
      } else {
        emit(ProviderOnlineStatus(
          isOnline: true,
          subscribedCategories: event.serviceCategories ?? ['general'],
        ));
      }
    } catch (e) {
      emit(ProviderError(message: 'Error going online: $e'));
    }
  }

  void _onGoOffline(
    ProviderGoOffline event,
    Emitter<ProviderState> emit,
  ) {
    _wsService.disconnect();
    _isOnline = false;

    if (state is ProviderLoaded) {
      emit((state as ProviderLoaded).copyWith(isOnline: false));
    } else {
      emit(const ProviderOnlineStatus(isOnline: false));
    }
  }

  Future<void> _onUpdateLocation(
    ProviderUpdateLocation event,
    Emitter<ProviderState> emit,
  ) async {
    // Send location via WebSocket
    _wsService.sendLocationUpdate(
      latitude: event.latitude,
      longitude: event.longitude,
      heading: event.heading,
      speed: event.speed,
    );
  }

  Future<void> _onLoadAvailableBookings(
    ProviderLoadAvailableBookingsRequested event,
    Emitter<ProviderState> emit,
  ) async {
    try {
      final response = await _apiService.getAvailableBookings(
        serviceType: event.serviceType,
        latitude: event.latitude,
        longitude: event.longitude,
        radiusKm: event.radiusKm ?? 50.0,
      );

      if (response['success'] == true && state is ProviderLoaded) {
        final bookings = (response['bookings'] as List<dynamic>? ?? [])
            .map((json) => BookingEntity.fromJson(json as Map<String, dynamic>))
            .toList();

        emit((state as ProviderLoaded).copyWith(availableBookings: bookings));
      }
    } catch (e) {
      emit(ProviderError(message: 'Error loading available bookings: $e'));
    }
  }

  Future<void> _onLoadBookingsRequested(
    ProviderLoadBookingsRequested event,
    Emitter<ProviderState> emit,
  ) async {
    // Delegate to dashboard loading which includes bookings
    add(const ProviderLoadDashboardRequested());
  }

  @override
  Future<void> close() {
    _bookingRequestSubscription?.cancel();
    _fareOfferSubscription?.cancel();
    return super.close();
  }
}
