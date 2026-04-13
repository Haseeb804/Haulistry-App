import 'package:equatable/equatable.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/domain/entities/vehicle_entity.dart';
import '../../../../core/domain/entities/fare_offer_entity.dart';
import '../../../../core/domain/entities/service_entity.dart';

abstract class ProviderState extends Equatable {
  const ProviderState();

  @override
  List<Object?> get props => [];
}

class ProviderInitial extends ProviderState {
  const ProviderInitial();
}

class ProviderLoading extends ProviderState {
  const ProviderLoading();
}

/// Main dashboard state with all provider data
class ProviderLoaded extends ProviderState {
  final List<BookingEntity> pendingBookings;
  final List<BookingEntity> activeBookings;
  final List<BookingEntity> completedBookings;
  final List<BookingEntity> availableBookings; // Bookings available to bid on
  final List<FareOfferEntity> pendingOffers;   // Provider's pending offers
  final List<VehicleEntity> vehicles;
  final List<ServiceEntity> services;           // Provider's services
  final double totalEarnings;
  final double pendingEarnings;
  final bool isOnline;

  const ProviderLoaded({
    required this.pendingBookings,
    required this.activeBookings,
    required this.completedBookings,
    this.availableBookings = const [],
    this.pendingOffers = const [],
    required this.vehicles,
    this.services = const [],
    required this.totalEarnings,
    required this.pendingEarnings,
    this.isOnline = false,
  });

  int get totalBookings =>
      pendingBookings.length + activeBookings.length + completedBookings.length;

  int get activeVehicles =>
      vehicles.where((v) => v.isAvailable).length;

  ProviderLoaded copyWith({
    List<BookingEntity>? pendingBookings,
    List<BookingEntity>? activeBookings,
    List<BookingEntity>? completedBookings,
    List<BookingEntity>? availableBookings,
    List<FareOfferEntity>? pendingOffers,
    List<VehicleEntity>? vehicles,
    List<ServiceEntity>? services,
    double? totalEarnings,
    double? pendingEarnings,
    bool? isOnline,
  }) {
    return ProviderLoaded(
      pendingBookings: pendingBookings ?? this.pendingBookings,
      activeBookings: activeBookings ?? this.activeBookings,
      completedBookings: completedBookings ?? this.completedBookings,
      availableBookings: availableBookings ?? this.availableBookings,
      pendingOffers: pendingOffers ?? this.pendingOffers,
      vehicles: vehicles ?? this.vehicles,
      services: services ?? this.services,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      pendingEarnings: pendingEarnings ?? this.pendingEarnings,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [
        pendingBookings,
        activeBookings,
        completedBookings,
        availableBookings,
        pendingOffers,
        vehicles,
        services,
        totalEarnings,
        pendingEarnings,
        isOnline,
      ];
}

class ProviderBookingActionInProgress extends ProviderState {
  final String bookingId;
  final String action;

  const ProviderBookingActionInProgress({
    required this.bookingId,
    required this.action,
  });

  @override
  List<Object?> get props => [bookingId, action];
}

class ProviderBookingActionSuccess extends ProviderState {
  final String message;
  final BookingEntity? acceptedBooking;

  const ProviderBookingActionSuccess({
    required this.message,
    this.acceptedBooking,
  });

  @override
  List<Object?> get props => [message, acceptedBooking];
}

class ProviderVehicleActionInProgress extends ProviderState {
  const ProviderVehicleActionInProgress();
}

class ProviderVehicleActionSuccess extends ProviderState {
  final String message;

  const ProviderVehicleActionSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class ProviderEarningsLoaded extends ProviderState {
  final double totalEarnings;
  final double thisMonth;
  final double thisWeek;
  final double today;
  final List<EarningEntry> recentEarnings;

  const ProviderEarningsLoaded({
    required this.totalEarnings,
    required this.thisMonth,
    required this.thisWeek,
    required this.today,
    required this.recentEarnings,
  });

  @override
  List<Object?> get props => [
        totalEarnings,
        thisMonth,
        thisWeek,
        today,
        recentEarnings,
      ];
}

class ProviderWithdrawalInProgress extends ProviderState {
  const ProviderWithdrawalInProgress();
}

class ProviderWithdrawalSuccess extends ProviderState {
  final String message;

  const ProviderWithdrawalSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class ProviderError extends ProviderState {
  final String message;

  const ProviderError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ===== Fare Offer States =====

class ProviderOfferActionInProgress extends ProviderState {
  final String offerId;
  final String action;

  const ProviderOfferActionInProgress({
    required this.offerId,
    required this.action,
  });

  @override
  List<Object?> get props => [offerId, action];
}

class ProviderOfferCreatedSuccess extends ProviderState {
  final FareOfferEntity offer;

  const ProviderOfferCreatedSuccess({required this.offer});

  @override
  List<Object?> get props => [offer];
}

class ProviderOfferUpdatedSuccess extends ProviderState {
  final FareOfferEntity offer;
  final String message;

  const ProviderOfferUpdatedSuccess({
    required this.offer,
    required this.message,
  });

  @override
  List<Object?> get props => [offer, message];
}

/// State when provider's offer is accepted by seeker
class ProviderOfferAccepted extends ProviderState {
  final FareOfferEntity offer;
  final BookingEntity booking;

  const ProviderOfferAccepted({
    required this.offer,
    required this.booking,
  });

  @override
  List<Object?> get props => [offer, booking];
}

/// State when provider receives a counter offer from seeker
class ProviderCounterOfferReceived extends ProviderState {
  final String offerId;
  final double counterPrice;
  final double originalPrice;

  const ProviderCounterOfferReceived({
    required this.offerId,
    required this.counterPrice,
    required this.originalPrice,
  });

  @override
  List<Object?> get props => [offerId, counterPrice, originalPrice];
}

// ===== Online Status States =====

class ProviderOnlineStatus extends ProviderState {
  final bool isOnline;
  final List<String> subscribedCategories;
  final DateTime? lastLocationUpdate;

  const ProviderOnlineStatus({
    required this.isOnline,
    this.subscribedCategories = const [],
    this.lastLocationUpdate,
  });

  @override
  List<Object?> get props => [isOnline, subscribedCategories, lastLocationUpdate];
}

// Helper class for earnings entries
class EarningEntry extends Equatable {
  final String bookingId;
  final DateTime date;
  final double amount;
  final String serviceType;
  final String status; // 'pending', 'paid', 'withdrawn'

  const EarningEntry({
    required this.bookingId,
    required this.date,
    required this.amount,
    required this.serviceType,
    required this.status,
  });

  @override
  List<Object?> get props => [bookingId, date, amount, serviceType, status];
}

// ===== Service States =====

class ProviderServicesLoaded extends ProviderState {
  final List<ServiceEntity> services;

  const ProviderServicesLoaded({required this.services});

  @override
  List<Object?> get props => [services];
}

class ProviderServiceActionInProgress extends ProviderState {
  const ProviderServiceActionInProgress();
}

class ProviderServiceActionSuccess extends ProviderState {
  final String message;

  const ProviderServiceActionSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}
