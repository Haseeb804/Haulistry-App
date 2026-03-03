/// Fare Offer Entity - Represents a provider's bid on a booking (InDrive-style)
enum FareOfferStatus {
  pending,
  accepted,
  rejected,
  counterOffered,
  expired,
  withdrawn,
}

class FareOfferEntity {
  final String id;
  final String bookingId;
  final String providerId;
  final String vehicleId;
  final double offeredPrice;
  final double? counterPrice;
  final FareOfferStatus status;
  final String? message;
  final int? estimatedArrivalMinutes;
  final String? providerName;
  final double? providerRating;
  final String? providerPhone;
  final String? providerImage;
  final String? vehicleType;
  final String? vehicleNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;

  const FareOfferEntity({
    required this.id,
    required this.bookingId,
    required this.providerId,
    required this.vehicleId,
    required this.offeredPrice,
    this.counterPrice,
    this.status = FareOfferStatus.pending,
    this.message,
    this.estimatedArrivalMinutes,
    this.providerName,
    this.providerRating,
    this.providerPhone,
    this.providerImage,
    this.vehicleType,
    this.vehicleNumber,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
  });

  factory FareOfferEntity.fromJson(Map<String, dynamic> json) {
    return FareOfferEntity(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      providerId: json['providerId'] as String,
      vehicleId: json['vehicleId'] as String,
      offeredPrice: (json['offeredPrice'] as num).toDouble(),
      counterPrice: (json['counterPrice'] as num?)?.toDouble(),
      status: _parseStatus(json['status'] as String?),
      message: json['message'] as String?,
      estimatedArrivalMinutes: json['estimatedArrivalMinutes'] as int?,
      providerName: json['providerName'] as String?,
      providerRating: (json['providerRating'] as num?)?.toDouble(),
      providerPhone: json['providerPhone'] as String?,
      providerImage: json['providerImage'] as String?,
      vehicleType: json['vehicleType'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  static FareOfferStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return FareOfferStatus.pending;
      case 'accepted':
        return FareOfferStatus.accepted;
      case 'rejected':
        return FareOfferStatus.rejected;
      case 'counter_offered':
        return FareOfferStatus.counterOffered;
      case 'expired':
        return FareOfferStatus.expired;
      case 'withdrawn':
        return FareOfferStatus.withdrawn;
      default:
        return FareOfferStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'providerId': providerId,
      'vehicleId': vehicleId,
      'offeredPrice': offeredPrice,
      'counterPrice': counterPrice,
      'status': status.name,
      'message': message,
      'estimatedArrivalMinutes': estimatedArrivalMinutes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  FareOfferEntity copyWith({
    String? id,
    String? bookingId,
    String? providerId,
    String? vehicleId,
    double? offeredPrice,
    double? counterPrice,
    FareOfferStatus? status,
    String? message,
    int? estimatedArrivalMinutes,
    String? providerName,
    double? providerRating,
    String? providerPhone,
    String? providerImage,
    String? vehicleType,
    String? vehicleNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) {
    return FareOfferEntity(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      providerId: providerId ?? this.providerId,
      vehicleId: vehicleId ?? this.vehicleId,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      counterPrice: counterPrice ?? this.counterPrice,
      status: status ?? this.status,
      message: message ?? this.message,
      estimatedArrivalMinutes:
          estimatedArrivalMinutes ?? this.estimatedArrivalMinutes,
      providerName: providerName ?? this.providerName,
      providerRating: providerRating ?? this.providerRating,
      providerPhone: providerPhone ?? this.providerPhone,
      providerImage: providerImage ?? this.providerImage,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  /// Get the final/effective price (counter price if available, otherwise offered)
  double get effectivePrice => counterPrice ?? offeredPrice;

  /// Check if offer is still active (not expired, rejected, or withdrawn)
  bool get isActive =>
      status == FareOfferStatus.pending ||
      status == FareOfferStatus.counterOffered;
}
