import 'package:equatable/equatable.dart';

/// Booking entity representing a service booking
class BookingEntity extends Equatable {
  final String id;
  final String seekerId;
  final String? seekerName;
  final String? providerId;
  final String? providerName;
  final String? serviceId;
  final String? serviceName;
  final String? vehicleId;
  final String serviceType;
  final String status; // pending, accepted, in_progress, completed, cancelled
  final double pickupLatitude;
  final double pickupLongitude;
  final String pickupAddress;
  final double dropLatitude;
  final double dropLongitude;
  final String dropAddress;
  final double distanceInKm;
  final double estimatedPrice;
  final double? finalPrice;
  final int hours;
  final bool isUrgent;
  final DateTime scheduledDateTime;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? notes;
  final double? rating;
  final String? review;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookingEntity({
    required this.id,
    required this.seekerId,
    this.seekerName,
    this.providerId,
    this.providerName,
    this.serviceId,
    this.serviceName,
    this.vehicleId,
    required this.serviceType,
    required this.status,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.pickupAddress,
    required this.dropLatitude,
    required this.dropLongitude,
    required this.dropAddress,
    required this.distanceInKm,
    required this.estimatedPrice,
    this.finalPrice,
    this.hours = 1,
    this.isUrgent = false,
    required this.scheduledDateTime,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.notes,
    this.rating,
    this.review,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        seekerId,
        seekerName,
        providerId,
        providerName,
        serviceId,
        serviceName,
        vehicleId,
        serviceType,
        status,
        pickupLatitude,
        pickupLongitude,
        pickupAddress,
        dropLatitude,
        dropLongitude,
        dropAddress,
        distanceInKm,
        estimatedPrice,
        finalPrice,
        hours,
        isUrgent,
        scheduledDateTime,
        startedAt,
        completedAt,
        cancelledAt,
        cancellationReason,
        notes,
        rating,
        review,
        createdAt,
        updatedAt,
      ];

  BookingEntity copyWith({
    String? id,
    String? seekerId,
    String? seekerName,
    String? providerId,
    String? providerName,
    String? serviceId,
    String? serviceName,
    String? vehicleId,
    String? serviceType,
    String? status,
    double? pickupLatitude,
    double? pickupLongitude,
    String? pickupAddress,
    double? dropLatitude,
    double? dropLongitude,
    String? dropAddress,
    double? distanceInKm,
    double? estimatedPrice,
    double? finalPrice,
    int? hours,
    bool? isUrgent,
    DateTime? scheduledDateTime,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    String? notes,
    double? rating,
    String? review,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookingEntity(
      id: id ?? this.id,
      seekerId: seekerId ?? this.seekerId,
      seekerName: seekerName ?? this.seekerName,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceType: serviceType ?? this.serviceType,
      status: status ?? this.status,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropLatitude: dropLatitude ?? this.dropLatitude,
      dropLongitude: dropLongitude ?? this.dropLongitude,
      dropAddress: dropAddress ?? this.dropAddress,
      distanceInKm: distanceInKm ?? this.distanceInKm,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      hours: hours ?? this.hours,
      isUrgent: isUrgent ?? this.isUrgent,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      notes: notes ?? this.notes,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seekerId': seekerId,
      'seekerName': seekerName,
      'providerId': providerId,
      'providerName': providerName,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'vehicleId': vehicleId,
      'serviceType': serviceType,
      'status': status,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'pickupAddress': pickupAddress,
      'dropLatitude': dropLatitude,
      'dropLongitude': dropLongitude,
      'dropAddress': dropAddress,
      'distanceInKm': distanceInKm,
      'estimatedPrice': estimatedPrice,
      'finalPrice': finalPrice,
      'hours': hours,
      'isUrgent': isUrgent,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'notes': notes,
      'rating': rating,
      'review': review,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BookingEntity.fromJson(Map<String, dynamic> json) {
    return BookingEntity(
      id: json['id'] as String,
      seekerId: (json['seekerId'] ?? json['seeker_id']) as String,
      seekerName: (json['seekerName'] ?? json['seeker_name']) as String?,
      providerId: (json['providerId'] ?? json['provider_id']) as String?,
      providerName: (json['providerName'] ?? json['provider_name']) as String?,
      serviceId: (json['serviceId'] ?? json['service_id']) as String?,
      serviceName: (json['serviceName'] ?? json['service_name']) as String?,
      vehicleId: (json['vehicleId'] ?? json['vehicle_id']) as String?,
      serviceType: (json['serviceType'] ?? json['service_type']) as String,
      status: json['status'] as String,
      pickupLatitude: ((json['pickupLatitude'] ?? json['pickup_latitude']) as num).toDouble(),
      pickupLongitude: ((json['pickupLongitude'] ?? json['pickup_longitude']) as num).toDouble(),
      pickupAddress: (json['pickupAddress'] ?? json['pickup_address']) as String,
      dropLatitude: ((json['dropLatitude'] ?? json['drop_latitude']) as num).toDouble(),
      dropLongitude: ((json['dropLongitude'] ?? json['drop_longitude']) as num).toDouble(),
      dropAddress: (json['dropAddress'] ?? json['drop_address']) as String,
      distanceInKm: ((json['distanceInKm'] ?? json['distance_in_km']) as num).toDouble(),
      estimatedPrice: ((json['estimatedPrice'] ?? json['estimated_price']) as num).toDouble(),
      finalPrice: ((json['finalPrice'] ?? json['final_price']) as num?)?.toDouble(),
      hours: json['hours'] as int? ?? 1,
      isUrgent: (json['isUrgent'] ?? json['is_urgent']) as bool? ?? false,
      scheduledDateTime: DateTime.parse((json['scheduledDateTime'] ?? json['scheduled_date_time']) as String),
      startedAt: (json['startedAt'] ?? json['started_at']) != null
          ? DateTime.parse((json['startedAt'] ?? json['started_at']) as String)
          : null,
      completedAt: (json['completedAt'] ?? json['completed_at']) != null
          ? DateTime.parse((json['completedAt'] ?? json['completed_at']) as String)
          : null,
      cancelledAt: (json['cancelledAt'] ?? json['cancelled_at']) != null
          ? DateTime.parse((json['cancelledAt'] ?? json['cancelled_at']) as String)
          : null,
      cancellationReason: (json['cancellationReason'] ?? json['cancellation_reason']) as String?,
      notes: json['notes'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      review: json['review'] as String?,
      createdAt: DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
      updatedAt: DateTime.parse((json['updatedAt'] ?? json['updated_at']) as String),
    );
  }
}
