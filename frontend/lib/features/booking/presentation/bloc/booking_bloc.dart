import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_event.dart';
import 'booking_state.dart';
import '../../domain/services/booking_service.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/domain/entities/location_entity.dart';
import '../../../../core/constants/app_constants.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingService _bookingService;
  final BookingRepository _repository;
  final FirebaseAuth _auth;
  final ApiService _apiService;
  final NotificationService _notificationService;

  StreamSubscription<Map<String, dynamic>>? _fcmSubscription;

  BookingBloc({
    BookingService? bookingService,
    required BookingRepository repository,
    FirebaseAuth? auth,
    ApiService? apiService,
    NotificationService? notificationService,
  })  : _bookingService = bookingService ?? BookingService(),
        _repository = repository,
        _auth = auth ?? FirebaseAuth.instance,
        _apiService = apiService ?? ApiService.instance,
        _notificationService = notificationService ?? NotificationService(),
        super(const BookingInitial()) {
    // Booking Creation Events
    on<BookingServiceSelected>(_onServiceSelected);
    on<BookingPickupLocationSelected>(_onPickupLocationSelected);
    on<BookingDropLocationSelected>(_onDropLocationSelected);
    on<BookingDateTimeSelected>(_onDateTimeSelected);
    on<BookingCalculatePriceRequested>(_onCalculatePriceRequested);
    on<BookingNotesUpdated>(_onNotesUpdated);
    on<BookingSubmitRequested>(_onSubmitRequested);
    on<BookingReset>(_onReset);

    // Booking Lifecycle Events
    on<LoadBookingRequested>(_onLoadBooking);
    on<LoadUserBookingsRequested>(_onLoadUserBookings);
    on<LoadAvailableBookingsRequested>(_onLoadAvailableBookings);
    on<ProviderArrivingRequested>(_onProviderArriving);
    on<ProviderArrivedRequested>(_onProviderArrived);
    on<StartBookingRequested>(_onStartBooking);
    on<CompleteBookingRequested>(_onCompleteBooking);
    on<CancelBookingRequested>(_onCancelBooking);
    on<RateBookingRequested>(_onRateBooking);

    // Real-time Events
    on<BookingStatusReceived>(_onBookingStatusReceived);
    on<ProviderLocationReceived>(_onProviderLocationReceived);
    on<NewBookingRequestReceived>(_onNewBookingRequest);
    on<StartTrackingBooking>(_onStartTracking);
    on<StopTrackingBooking>(_onStopTracking);

    // Listen to FCM notifications
    _setupFcmListeners();
  }

  void _setupFcmListeners() {
    // Listen to FCM notifications for booking updates
    _fcmSubscription = _notificationService.notificationStream.listen((data) {
      final type = data['type'] as String?;
      final bookingId = data['bookingId'] as String?;
      
      if (type == 'booking_status' && bookingId != null) {
        // Booking status update
        add(BookingStatusReceived(
          bookingId: bookingId,
          status: data['status'] as String? ?? '',
          data: data,
        ));
      } else if (type == 'location_update' && bookingId != null) {
        // Location update
        add(ProviderLocationReceived(
          bookingId: bookingId,
          location: LocationEntity.fromJson(data),
        ));
      } else if (type == 'new_booking_request') {
        // New booking request (for providers)
        add(NewBookingRequestReceived(
          booking: BookingEntity.fromJson(data),
        ));
      }
    });
  }

  void _onServiceSelected(
    BookingServiceSelected event,
    Emitter<BookingState> emit,
  ) {
    if (state is BookingInProgress) {
      emit((state as BookingInProgress).copyWith(
        serviceType: event.serviceType,
        service: event.service,
      ));
    } else {
      emit(BookingInProgress(
        serviceType: event.serviceType,
        service: event.service,
      ));
    }
  }

  void _onPickupLocationSelected(
    BookingPickupLocationSelected event,
    Emitter<BookingState> emit,
  ) {
    final currentState = state is BookingInProgress
        ? state as BookingInProgress
        : const BookingInProgress();

    emit(currentState.copyWith(
      pickupLocation: event.location,
      pickupAddress: event.address,
      // Reset distance and price when location changes
      distance: null,
      estimatedPrice: null,
    ));
  }

  void _onDropLocationSelected(
    BookingDropLocationSelected event,
    Emitter<BookingState> emit,
  ) {
    final currentState = state is BookingInProgress
        ? state as BookingInProgress
        : const BookingInProgress();

    emit(currentState.copyWith(
      dropLocation: event.location,
      dropAddress: event.address,
      // Reset distance and price when location changes
      distance: null,
      estimatedPrice: null,
    ));
  }

  void _onDateTimeSelected(
    BookingDateTimeSelected event,
    Emitter<BookingState> emit,
  ) {
    final currentState = state is BookingInProgress
        ? state as BookingInProgress
        : const BookingInProgress();

    emit(currentState.copyWith(
      scheduledDateTime: event.dateTime,
    ));
  }

  Future<void> _onCalculatePriceRequested(
    BookingCalculatePriceRequested event,
    Emitter<BookingState> emit,
  ) async {
    final currentState = state is BookingInProgress
        ? state as BookingInProgress
        : const BookingInProgress();

    if (!currentState.isReadyForPriceCalculation) {
      emit(BookingError(
        message: 'Please select pickup and drop locations first',
        currentState: currentState,
      ));
      return;
    }

    emit(BookingCalculating(currentState: currentState));

    try {
      // Calculate distance
      final distance = await _bookingService.calculateDistance(
        currentState.pickupLocation!,
        currentState.dropLocation!,
      );

      // Calculate price - use service entity pricing if available
      double price;
      if (currentState.service != null) {
        // Use real service pricing from provider
        price = currentState.service!.calculatePrice(
          distanceKm: distance,
          hours: 1, // Default 1 hour, can be adjusted later
        );
      } else {
        // Fallback to static pricing for legacy flows
        price = _bookingService.calculatePrice(
          serviceType: currentState.serviceType!,
          distance: distance,
        );
      }

      emit(currentState.copyWith(
        distance: distance,
        estimatedPrice: price,
      ));
    } catch (e) {
      emit(BookingError(
        message: 'Error calculating price: ${e.toString()}',
        currentState: currentState,
      ));
    }
  }

  void _onNotesUpdated(
    BookingNotesUpdated event,
    Emitter<BookingState> emit,
  ) {
    final currentState = state is BookingInProgress
        ? state as BookingInProgress
        : const BookingInProgress();

    emit(currentState.copyWith(
      notes: event.notes,
    ));
  }

  Future<void> _onSubmitRequested(
    BookingSubmitRequested event,
    Emitter<BookingState> emit,
  ) async {
    final currentState = state is BookingInProgress
        ? state as BookingInProgress
        : const BookingInProgress();

    if (!currentState.isReadyForSubmission) {
      emit(BookingError(
        message: 'Please complete all required fields',
        currentState: currentState,
      ));
      return;
    }

    emit(BookingSubmitting(bookingData: currentState));

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Submit booking to backend with service info
      final booking = await _repository.createBooking(
        userId: user.uid,
        serviceType: currentState.serviceType!,
        pickupLocation: currentState.pickupAddress ?? '',
        dropoffLocation: currentState.dropAddress ?? '',
        pickupLat: currentState.pickupLocation!.latitude,
        pickupLng: currentState.pickupLocation!.longitude,
        dropoffLat: currentState.dropLocation!.latitude,
        dropoffLng: currentState.dropLocation!.longitude,
        scheduledDate: currentState.scheduledDateTime!.toIso8601String(),
        estimatedPrice: currentState.estimatedPrice!,
        distance: currentState.distance!,
        // Include service info for direct booking or offer-based pricing
        serviceId: currentState.service?.id,
        providerId: currentState.service?.providerId,
        vehicleId: currentState.service?.vehicleId,
        notes: currentState.notes,
      );

      emit(BookingSuccess(
        bookingId: booking.id,
        message: 'Booking created successfully!',
        bookingData: currentState,
      ));
    } catch (e) {
      emit(BookingError(
        message: 'Error creating booking: ${e.toString()}',
        currentState: currentState,
      ));
    }
  }

  void _onReset(
    BookingReset event,
    Emitter<BookingState> emit,
  ) {
    emit(const BookingInitial());
  }

  // ===== Booking Lifecycle Handlers =====

  Future<void> _onLoadBooking(
    LoadBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingsLoading());

    try {
      final response = await _apiService.getBooking(event.bookingId);

      if (response['success'] == true) {
        final booking = BookingEntity.fromJson(
          response['booking'] as Map<String, dynamic>,
        );

        // Emit appropriate state based on booking status
        emit(_getStateForBooking(booking));
      } else {
        emit(BookingError(message: response['message'] ?? 'Failed to load booking'));
      }
    } catch (e) {
      emit(BookingError(message: 'Error loading booking: $e'));
    }
  }

  Future<void> _onLoadUserBookings(
    LoadUserBookingsRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingsLoading());

    try {
      final response = event.isProvider
          ? await _apiService.getProviderBookings(
              providerId: event.userId,
              status: event.status,
            )
          : await _apiService.getSeekerBookings(
              seekerId: event.userId,
              status: event.status,
            );

      if (response['success'] == true) {
        final bookingsJson = response['bookings'] as List<dynamic>? ?? [];
        final bookings = bookingsJson
            .map((json) => BookingEntity.fromJson(json as Map<String, dynamic>))
            .toList();

        emit(BookingsLoaded(
          bookings: bookings,
          isProvider: event.isProvider,
        ));
      } else {
        emit(BookingError(message: response['message'] ?? 'Failed to load bookings'));
      }
    } catch (e) {
      emit(BookingError(message: 'Error loading bookings: $e'));
    }
  }

  Future<void> _onLoadAvailableBookings(
    LoadAvailableBookingsRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingsLoading());

    try {
      final response = await _apiService.getAvailableBookings(
        serviceType: event.serviceType,
        latitude: event.latitude,
        longitude: event.longitude,
        radiusKm: event.radiusKm ?? 50.0,
      );

      if (response['success'] == true) {
        final bookingsJson = response['bookings'] as List<dynamic>? ?? [];
        final bookings = bookingsJson
            .map((json) => BookingEntity.fromJson(json as Map<String, dynamic>))
            .toList();

        emit(AvailableBookingsLoaded(bookings: bookings));
      } else {
        emit(BookingError(message: response['message'] ?? 'Failed to load available bookings'));
      }
    } catch (e) {
      emit(BookingError(message: 'Error loading available bookings: $e'));
    }
  }

  Future<void> _onProviderArriving(
    ProviderArrivingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingActionProcessing(bookingId: event.bookingId, action: 'arriving'));

    try {
      final response = await _apiService.providerArriving(
        event.bookingId,
        estimatedMinutes: event.estimatedMinutes,
      );

      if (response['success'] == true) {
        final booking = BookingEntity.fromJson(
          response['booking'] as Map<String, dynamic>,
        );
        emit(ProviderArrivingState(
          booking: booking,
          estimatedMinutes: event.estimatedMinutes,
        ));
      } else {
        emit(BookingError(message: response['message'] ?? 'Failed to update status'));
      }
    } catch (e) {
      emit(BookingError(message: 'Error updating status: $e'));
    }
  }

  Future<void> _onProviderArrived(
    ProviderArrivedRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingActionProcessing(bookingId: event.bookingId, action: 'arrived'));

    try {
      final response = await _apiService.providerArrived(event.bookingId);

      if (response['success'] == true) {
        final booking = BookingEntity.fromJson(
          response['booking'] as Map<String, dynamic>,
        );
        emit(ProviderArrivedState(booking: booking));
      } else {
        emit(BookingError(message: response['message'] ?? 'Failed to update status'));
      }
    } catch (e) {
      emit(BookingError(message: 'Error updating status: $e'));
    }
  }

  Future<void> _onStartBooking(
    StartBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingActionProcessing(bookingId: event.bookingId, action: 'starting'));

    try {
      final response = await _apiService.startBooking(event.bookingId);

      if (response['success'] == true) {
        final booking = BookingEntity.fromJson(
          response['booking'] as Map<String, dynamic>,
        );
        emit(BookingInProgressState(
          booking: booking,
          startedAt: booking.startedAt ?? DateTime.now(),
        ));
      } else {
        emit(BookingError(message: response['message'] ?? 'Failed to start booking'));
      }
    } catch (e) {
      emit(BookingError(message: 'Error starting booking: $e'));
    }
  }

  Future<void> _onCompleteBooking(
    CompleteBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingActionProcessing(bookingId: event.bookingId, action: 'completing'));

    try {
      final response = await _apiService.completeBooking(
        event.bookingId,
        finalPrice: event.finalPrice,
      );

      if (response['success'] == true) {
        final booking = BookingEntity.fromJson(
          response['booking'] as Map<String, dynamic>,
        );
        emit(BookingCompletedState(
          booking: booking,
          finalPrice: booking.finalPrice ?? booking.estimatedPrice,
        ));
      } else {
        emit(BookingError(message: response['message'] ?? 'Failed to complete booking'));
      }
    } catch (e) {
      emit(BookingError(message: 'Error completing booking: $e'));
    }
  }

  Future<void> _onCancelBooking(
    CancelBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingActionProcessing(bookingId: event.bookingId, action: 'cancelling'));

    try {
      final user = _auth.currentUser;
      final response = await _apiService.cancelBooking(
        event.bookingId,
        reason: event.reason,
      );

      if (response['success'] == true) {
        final booking = BookingEntity.fromJson(
          response['booking'] as Map<String, dynamic>,
        );
        emit(BookingCancelledState(
          booking: booking,
          reason: event.reason,
          cancelledBy: user?.uid ?? 'unknown',
        ));
      } else {
        emit(BookingError(message: response['message'] ?? 'Failed to cancel booking'));
      }
    } catch (e) {
      emit(BookingError(message: 'Error cancelling booking: $e'));
    }
  }

  Future<void> _onRateBooking(
    RateBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingActionProcessing(bookingId: event.bookingId, action: 'rating'));

    try {
      final response = await _apiService.rateBooking(
        event.bookingId,
        rating: event.rating,
        review: event.review,
      );

      if (response['success'] == true) {
        final booking = BookingEntity.fromJson(
          response['booking'] as Map<String, dynamic>,
        );
        emit(BookingCompletedState(
          booking: booking,
          finalPrice: booking.finalPrice ?? booking.estimatedPrice,
          hasRated: true,
        ));
      } else {
        emit(BookingError(message: response['message'] ?? 'Failed to rate booking'));
      }
    } catch (e) {
      emit(BookingError(message: 'Error rating booking: $e'));
    }
  }

  // ===== Real-time Event Handlers =====

  void _onBookingStatusReceived(
    BookingStatusReceived event,
    Emitter<BookingState> emit,
  ) {
    final currentState = state;

    // Only update if we're tracking this booking
    if (currentState is BookingTracking &&
        currentState.booking.id == event.bookingId) {
      final updatedBooking = currentState.booking.copyWith(
        status: event.data?['status'] as String? ?? event.status,
      );
      emit(_getStateForBooking(updatedBooking));
    }
  }

  void _onProviderLocationReceived(
    ProviderLocationReceived event,
    Emitter<BookingState> emit,
  ) {
    final currentState = state;

    if (currentState is BookingTracking &&
        currentState.booking.id == event.bookingId) {
      emit(currentState.copyWith(
        providerLocation: event.location,
      ));
    } else if (currentState is ProviderArrivingState &&
        currentState.booking.id == event.bookingId) {
      emit(ProviderArrivingState(
        booking: currentState.booking,
        providerLocation: event.location,
        estimatedMinutes: currentState.estimatedMinutes,
      ));
    }
  }

  void _onNewBookingRequest(
    NewBookingRequestReceived event,
    Emitter<BookingState> emit,
  ) {
    final currentState = state;

    // Add to available bookings if we're showing that list
    if (currentState is AvailableBookingsLoaded) {
      emit(AvailableBookingsLoaded(
        bookings: [event.booking, ...currentState.bookings],
      ));
    }
  }

  Future<void> _onStartTracking(
    StartTrackingBooking event,
    Emitter<BookingState> emit,
  ) async {
    // Load current booking state (FCM handles real-time updates)
    add(LoadBookingRequested(bookingId: event.bookingId));
  }

  void _onStopTracking(
    StopTrackingBooking event,
    Emitter<BookingState> emit,
  ) {
    // No-op for FCM - notifications continue until booking is complete
  }

  // ===== Helper Methods =====

  BookingState _getStateForBooking(BookingEntity booking) {
    switch (booking.status) {
      case AppConstants.statusPending:
        return BookingTracking(booking: booking);
      case AppConstants.statusAccepted:
      case AppConstants.statusActive:
      case AppConstants.statusProviderArriving:
        return ProviderArrivingState(booking: booking);
      case AppConstants.statusProviderArrived:
        return ProviderArrivedState(booking: booking);
      case AppConstants.statusInProgress:
        return BookingInProgressState(
          booking: booking,
          startedAt: booking.startedAt ?? DateTime.now(),
        );
      case AppConstants.statusCompleted:
        return BookingCompletedState(
          booking: booking,
          finalPrice: booking.finalPrice ?? booking.estimatedPrice,
          hasRated: booking.rating != null,
        );
      case AppConstants.statusCancelled:
        return BookingCancelledState(
          booking: booking,
          reason: booking.cancellationReason ?? 'Cancelled',
          cancelledBy: 'unknown',
        );
      default:
        return BookingTracking(booking: booking);
    }
  }

  @override
  Future<void> close() {
    _fcmSubscription?.cancel();
    return super.close();
  }
}
