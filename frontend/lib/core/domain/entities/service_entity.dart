/// Service Entity - Represents a service offered by a provider
class ServiceEntity {
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
  final String? providerName;
  final double? providerRating;
  final String? vehicleType;
  final String? vehicleNumber;
  final double? providerLatitude;
  final double? providerLongitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// JSON-encoded string of service-specific extra fields (stored in Neo4j).
  final String? extraFields;

  const ServiceEntity({
    required this.id,
    required this.providerId,
    required this.vehicleId,
    required this.name,
    this.description,
    this.imageUrl,
    this.basePrice = 0.0,
    this.pricePerKm = 0.0,
    this.pricePerHour = 0.0,
    this.category = 'general',
    this.isActive = true,
    this.providerName,
    this.providerRating,
    this.vehicleType,
    this.vehicleNumber,
    this.providerLatitude,
    this.providerLongitude,
    required this.createdAt,
    required this.updatedAt,
    this.extraFields,
  });

  factory ServiceEntity.fromJson(Map<String, dynamic> json) {
    return ServiceEntity(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      vehicleId: json['vehicleId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0.0,
      pricePerKm: (json['pricePerKm'] as num?)?.toDouble() ?? 0.0,
      pricePerHour: (json['pricePerHour'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'general',
      isActive: json['isActive'] as bool? ?? true,
      providerName: json['providerName'] as String?,
      providerRating: (json['providerRating'] as num?)?.toDouble(),
      vehicleType: json['vehicleType'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      providerLatitude: (json['providerLatitude'] as num?)?.toDouble(),
      providerLongitude: (json['providerLongitude'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      extraFields: json['extraFields'] as String?,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'extraFields': extraFields,
    };
  }

  ServiceEntity copyWith({
    String? id,
    String? providerId,
    String? vehicleId,
    String? name,
    String? description,
    String? imageUrl,
    double? basePrice,
    double? pricePerKm,
    double? pricePerHour,
    String? category,
    bool? isActive,
    String? providerName,
    double? providerRating,
    String? vehicleType,
    String? vehicleNumber,
    double? providerLatitude,
    double? providerLongitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? extraFields,
  }) {
    return ServiceEntity(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      basePrice: basePrice ?? this.basePrice,
      pricePerKm: pricePerKm ?? this.pricePerKm,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      providerName: providerName ?? this.providerName,
      providerRating: providerRating ?? this.providerRating,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      providerLatitude: providerLatitude ?? this.providerLatitude,
      providerLongitude: providerLongitude ?? this.providerLongitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}
