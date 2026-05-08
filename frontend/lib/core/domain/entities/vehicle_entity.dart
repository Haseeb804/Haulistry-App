import 'package:equatable/equatable.dart';

/// Vehicle entity representing provider's vehicle
class VehicleEntity extends Equatable {
  final String id;
  final String providerId;
  final String vehicleType; // Sand Trolley, Harvester, etc.
  final String vehicleNumber;
  final String? vehicleModel;
  final String? vehicleYear;
  final String? vehicleImageUrl;
  final String? vehicleImageBase64; // Base64 encoded image
  final bool isAvailable;
  final double? capacity;
  final String? extraFields;
  final String? vehicleLicenseImageBase64; // vehicle registration document photo
  final DateTime createdAt;
  final DateTime updatedAt;

  const VehicleEntity({
    required this.id,
    required this.providerId,
    required this.vehicleType,
    required this.vehicleNumber,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleImageUrl,
    this.vehicleImageBase64,
    this.isAvailable = true,
    this.capacity,
    this.extraFields,
    this.vehicleLicenseImageBase64,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        providerId,
        vehicleType,
        vehicleNumber,
        vehicleModel,
        vehicleYear,
        vehicleImageUrl,
        vehicleImageBase64,
        isAvailable,
        capacity,
        extraFields,
        vehicleLicenseImageBase64,
        createdAt,
        updatedAt,
      ];

  VehicleEntity copyWith({
    String? id,
    String? providerId,
    String? vehicleType,
    String? vehicleNumber,
    String? vehicleModel,
    String? vehicleYear,
    String? vehicleImageUrl,
    String? vehicleImageBase64,
    bool? isAvailable,
    double? capacity,
    String? extraFields,
    String? vehicleLicenseImageBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VehicleEntity(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleImageUrl: vehicleImageUrl ?? this.vehicleImageUrl,
      vehicleImageBase64: vehicleImageBase64 ?? this.vehicleImageBase64,
      isAvailable: isAvailable ?? this.isAvailable,
      capacity: capacity ?? this.capacity,
      extraFields: extraFields ?? this.extraFields,
      vehicleLicenseImageBase64: vehicleLicenseImageBase64 ?? this.vehicleLicenseImageBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerId': providerId,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'vehicleModel': vehicleModel,
      'vehicleYear': vehicleYear,
      'vehicleImageUrl': vehicleImageUrl,
      'vehicleImageBase64': vehicleImageBase64,
      'isAvailable': isAvailable,
      'capacity': capacity,
      'extraFields': extraFields,
      'vehicleLicenseImageBase64': vehicleLicenseImageBase64,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory VehicleEntity.fromJson(Map<String, dynamic> json) {
    return VehicleEntity(
      id: json['id'] as String,
      providerId: (json['providerId'] ?? json['provider_id']) as String,
      vehicleType: (json['vehicleType'] ?? json['vehicle_type']) as String,
      vehicleNumber: (json['vehicleNumber'] ?? json['vehicle_number']) as String,
      vehicleModel: (json['vehicleModel'] ?? json['vehicle_model']) as String?,
      vehicleYear: (json['vehicleYear'] ?? json['vehicle_year']) as String?,
      vehicleImageUrl: (json['vehicleImageUrl'] ?? json['vehicle_image_url']) as String?,
      vehicleImageBase64: (json['vehicleImageBase64'] ?? json['vehicle_image_base64']) as String?,
      isAvailable: (json['isAvailable'] ?? json['is_available']) as bool? ?? true,
      capacity: (json['capacity'] as num?)?.toDouble(),
      extraFields: json['extraFields'] as String?,
      vehicleLicenseImageBase64: json['vehicleLicenseImageBase64'] as String?,
      createdAt: DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
      updatedAt: DateTime.parse((json['updatedAt'] ?? json['updated_at']) as String),
    );
  }
}
