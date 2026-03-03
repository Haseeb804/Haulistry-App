import 'package:equatable/equatable.dart';

/// Service Entity - Represents a real service offered by a verified provider
class ServiceEntity extends Equatable {
  final String id;
  final String providerId;
  final String vehicleId;
  final String name;
  final String? description;
  final String? imageUrl;
  final double basePrice;
  final double pricePerKm;
  final double pricePerHour;
  final String category;
  final bool isActive;
  
  // Provider info
  final String? providerName;
  final double? providerRating;
  final double? providerLatitude;
  final double? providerLongitude;
  final String? providerImageUrl;
  
  // Vehicle info
  final String? vehicleType;
  final String? vehicleNumber;
  final String? vehicleImageBase64;
  
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ServiceEntity({
    required this.id,
    required this.providerId,
    required this.vehicleId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.basePrice,
    required this.pricePerKm,
    required this.pricePerHour,
    required this.category,
    this.isActive = true,
    this.providerName,
    this.providerRating,
    this.providerLatitude,
    this.providerLongitude,
    this.providerImageUrl,
    this.vehicleType,
    this.vehicleNumber,
    this.vehicleImageBase64,
    this.createdAt,
    this.updatedAt,
  });

  /// Calculate estimated price based on distance and hours
  double calculatePrice({required double distanceKm, int hours = 1}) {
    return basePrice + (pricePerKm * distanceKm) + (pricePerHour * hours);
  }

  /// Factory constructor from JSON
  factory ServiceEntity.fromJson(Map<String, dynamic> json) {
    return ServiceEntity(
      id: json['id'] ?? '',
      providerId: json['providerId'] ?? '',
      vehicleId: json['vehicleId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['imageUrl'],
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      pricePerKm: (json['pricePerKm'] ?? 0).toDouble(),
      pricePerHour: (json['pricePerHour'] ?? 0).toDouble(),
      category: json['category'] ?? 'general',
      isActive: json['isActive'] ?? true,
      providerName: json['providerName'],
      providerRating: json['providerRating']?.toDouble(),
      providerLatitude: json['providerLatitude']?.toDouble(),
      providerLongitude: json['providerLongitude']?.toDouble(),
      providerImageUrl: json['providerImageUrl'],
      vehicleType: json['vehicleType'],
      vehicleNumber: json['vehicleNumber'],
      vehicleImageBase64: json['vehicleImageBase64'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerId': providerId,
      'vehicleId': vehicleId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'basePrice': basePrice,
      'pricePerKm': pricePerKm,
      'pricePerHour': pricePerHour,
      'category': category,
      'isActive': isActive,
      'providerName': providerName,
      'providerRating': providerRating,
      'providerLatitude': providerLatitude,
      'providerLongitude': providerLongitude,
      'providerImageUrl': providerImageUrl,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'vehicleImageBase64': vehicleImageBase64,
    };
  }

  @override
  List<Object?> get props => [
    id, providerId, vehicleId, name, category, isActive,
  ];
}
