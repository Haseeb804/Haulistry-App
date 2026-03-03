import 'package:equatable/equatable.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/domain/entities/vehicle_entity.dart';
import '../../../../core/domain/entities/fare_offer_entity.dart';
import '../../../../core/domain/entities/service_entity.dart';

abstract class ProviderEvent extends Equatable {
  const ProviderEvent();

  @override
  List<Object?> get props => [];
}

// ===== Dashboard Events =====

class ProviderLoadDashboardRequested extends ProviderEvent {
  const ProviderLoadDashboardRequested();
}

// ===== Booking Events =====

class ProviderLoadBookingsRequested extends ProviderEvent {
  const ProviderLoadBookingsRequested();
}

class ProviderLoadAvailableBookingsRequested extends ProviderEvent {
  final String? serviceType;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;

  const ProviderLoadAvailableBookingsRequested({
    this.serviceType,
    this.latitude,
    this.longitude,
    this.radiusKm,
  });

  @override
  List<Object?> get props => [serviceType, latitude, longitude, radiusKm];
}

class ProviderAcceptBookingRequested extends ProviderEvent {
  final String bookingId;

  const ProviderAcceptBookingRequested({required this.bookingId});

  @override
  List<Object?> get props => [bookingId];
}

class ProviderRejectBookingRequested extends ProviderEvent {
  final String bookingId;
  final String reason;

  const ProviderRejectBookingRequested({
    required this.bookingId,
    required this.reason,
  });

  @override
  List<Object?> get props => [bookingId, reason];
}

class ProviderStartBookingRequested extends ProviderEvent {
  final String bookingId;

  const ProviderStartBookingRequested({required this.bookingId});

  @override
  List<Object?> get props => [bookingId];
}

class ProviderCompleteBookingRequested extends ProviderEvent {
  final String bookingId;

  const ProviderCompleteBookingRequested({required this.bookingId});

  @override
  List<Object?> get props => [bookingId];
}

class ProviderCancelBookingRequested extends ProviderEvent {
  final String bookingId;
  final String reason;

  const ProviderCancelBookingRequested({
    required this.bookingId,
    required this.reason,
  });

  @override
  List<Object?> get props => [bookingId, reason];
}

// Vehicle Events
class ProviderLoadVehiclesRequested extends ProviderEvent {
  const ProviderLoadVehiclesRequested();
}

class ProviderAddVehicleRequested extends ProviderEvent {
  final String vehicleType;
  final String vehicleModel;
  final String vehicleYear;
  final String licensePlate;
  final double capacity;
  final double pricePerHour;
  final double pricePerKm;
  final List<String> imageUrls;
  final String? vehicleImageBase64;

  const ProviderAddVehicleRequested({
    required this.vehicleType,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.licensePlate,
    required this.capacity,
    required this.pricePerHour,
    required this.pricePerKm,
    required this.imageUrls,
    this.vehicleImageBase64,
  });

  @override
  List<Object?> get props => [vehicleType, vehicleModel, vehicleYear, licensePlate, capacity, pricePerHour, pricePerKm, imageUrls, vehicleImageBase64];
}

class ProviderUpdateVehicleRequested extends ProviderEvent {
  final String vehicleId;
  final Map<String, dynamic> updates;

  const ProviderUpdateVehicleRequested({
    required this.vehicleId,
    required this.updates,
  });

  @override
  List<Object?> get props => [vehicleId, updates];
}

class ProviderDeleteVehicleRequested extends ProviderEvent {
  final String vehicleId;

  const ProviderDeleteVehicleRequested({required this.vehicleId});

  @override
  List<Object?> get props => [vehicleId];
}

class ProviderToggleVehicleAvailability extends ProviderEvent {
  final String vehicleId;
  final bool isAvailable;

  const ProviderToggleVehicleAvailability({
    required this.vehicleId,
    required this.isAvailable,
  });

  @override
  List<Object?> get props => [vehicleId, isAvailable];
}

// Earnings Events
class ProviderLoadEarningsRequested extends ProviderEvent {
  final DateTime? startDate;
  final DateTime? endDate;

  const ProviderLoadEarningsRequested({
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [startDate, endDate];
}

class ProviderRequestWithdrawal extends ProviderEvent {
  final double amount;
  final String accountDetails;

  const ProviderRequestWithdrawal({
    required this.amount,
    required this.accountDetails,
  });

  @override
  List<Object?> get props => [amount, accountDetails];
}

// ===== Fare Offer Events (InDrive-style bidding) =====

/// Provider creates a fare offer for a booking
class ProviderCreateFareOfferRequested extends ProviderEvent {
  final String bookingId;
  final String vehicleId;
  final double offeredPrice;
  final String? message;
  final int? estimatedArrivalMinutes;

  const ProviderCreateFareOfferRequested({
    required this.bookingId,
    required this.vehicleId,
    required this.offeredPrice,
    this.message,
    this.estimatedArrivalMinutes,
  });

  @override
  List<Object?> get props => [bookingId, vehicleId, offeredPrice, message, estimatedArrivalMinutes];
}

/// Provider updates their offer price (responding to counter offer)
class ProviderUpdateOfferPriceRequested extends ProviderEvent {
  final String offerId;
  final double newPrice;
  final String? message;

  const ProviderUpdateOfferPriceRequested({
    required this.offerId,
    required this.newPrice,
    this.message,
  });

  @override
  List<Object?> get props => [offerId, newPrice, message];
}

/// Provider withdraws their offer
class ProviderWithdrawOfferRequested extends ProviderEvent {
  final String offerId;

  const ProviderWithdrawOfferRequested({required this.offerId});

  @override
  List<Object?> get props => [offerId];
}

/// Provider loads their pending offers
class ProviderLoadOffersRequested extends ProviderEvent {
  final String? status;

  const ProviderLoadOffersRequested({this.status});

  @override
  List<Object?> get props => [status];
}

// ===== WebSocket Events =====

/// New booking request received via WebSocket
class ProviderNewBookingReceived extends ProviderEvent {
  final BookingEntity booking;

  const ProviderNewBookingReceived({required this.booking});

  @override
  List<Object?> get props => [booking];
}

/// Offer status updated via WebSocket
class ProviderOfferStatusReceived extends ProviderEvent {
  final String offerId;
  final String status;
  final double? counterPrice;

  const ProviderOfferStatusReceived({
    required this.offerId,
    required this.status,
    this.counterPrice,
  });

  @override
  List<Object?> get props => [offerId, status, counterPrice];
}

// ===== Online Status Events =====

/// Provider goes online to receive booking requests
class ProviderGoOnline extends ProviderEvent {
  final List<String>? serviceCategories;

  const ProviderGoOnline({this.serviceCategories});

  @override
  List<Object?> get props => [serviceCategories];
}

/// Provider goes offline
class ProviderGoOffline extends ProviderEvent {
  const ProviderGoOffline();
}

/// Provider updates location
class ProviderUpdateLocation extends ProviderEvent {
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;

  const ProviderUpdateLocation({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
  });

  @override
  List<Object?> get props => [latitude, longitude, heading, speed];
}

// ===== Service Events =====

class ProviderLoadServicesRequested extends ProviderEvent {
  const ProviderLoadServicesRequested();
}

class ProviderLoadVehicleServicesRequested extends ProviderEvent {
  final String vehicleId;

  const ProviderLoadVehicleServicesRequested({required this.vehicleId});

  @override
  List<Object?> get props => [vehicleId];
}

class ProviderAddServiceRequested extends ProviderEvent {
  final String vehicleId;
  final String name;
  final String description;
  final String? imageUrl;
  final double basePrice;
  final double pricePerKm;
  final double pricePerHour;
  final String category;

  const ProviderAddServiceRequested({
    required this.vehicleId,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.basePrice,
    required this.pricePerKm,
    required this.pricePerHour,
    required this.category,
  });

  @override
  List<Object?> get props => [
        vehicleId,
        name,
        description,
        imageUrl,
        basePrice,
        pricePerKm,
        pricePerHour,
        category,
      ];
}

class ProviderUpdateServiceRequested extends ProviderEvent {
  final String serviceId;
  final Map<String, dynamic> updates;

  const ProviderUpdateServiceRequested({
    required this.serviceId,
    required this.updates,
  });

  @override
  List<Object?> get props => [serviceId, updates];
}

class ProviderDeleteServiceRequested extends ProviderEvent {
  final String serviceId;

  const ProviderDeleteServiceRequested({required this.serviceId});

  @override
  List<Object?> get props => [serviceId];
}
