import 'package:equatable/equatable.dart';

/// User entity representing both service seekers and providers
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String role; // 'seeker' or 'provider'
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerified;
  final bool isActive;
  
  // Provider-specific fields
  final String? cnic;
  final String? drivingLicense;
  final double? rating;
  final int? completedBookings;
  
  // Location
  final double? latitude;
  final double? longitude;
  final String? address;

  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isVerified = true,
    this.isActive = true,
    this.cnic,
    this.drivingLicense,
    this.rating,
    this.completedBookings,
    this.latitude,
    this.longitude,
    this.address,
  });

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        phone,
        role,
        profileImageUrl,
        createdAt,
        updatedAt,
        isVerified,
        isActive,
        cnic,
        drivingLicense,
        rating,
        completedBookings,
        latitude,
        longitude,
        address,
      ];

  UserEntity copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? role,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerified,
    bool? isActive,
    String? cnic,
    String? drivingLicense,
    double? rating,
    int? completedBookings,
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      cnic: cnic ?? this.cnic,
      drivingLicense: drivingLicense ?? this.drivingLicense,
      rating: rating ?? this.rating,
      completedBookings: completedBookings ?? this.completedBookings,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isVerified': isVerified,
      'isActive': isActive,
      'cnic': cnic,
      'drivingLicense': drivingLicense,
      'rating': rating,
      'completedBookings': completedBookings,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] as String,
      email: (json['email'] ?? '') as String,
      name: json['name'] as String,
      phone: (json['phone'] ?? json['phoneNumber'] ?? '') as String,
      role: json['role'] as String,
      profileImageUrl: (json['profileImageUrl'] ?? json['profile_image_url']) as String?,
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
      isVerified: (json['isVerified'] ?? json['is_verified']) as bool? ?? true,
      isActive: (json['isActive'] ?? json['is_active']) as bool? ?? true,
      cnic: json['cnic'] as String?,
      drivingLicense: (json['drivingLicense'] ?? json['driving_license']) as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      completedBookings: (json['completedBookings'] ?? json['completed_bookings']) as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.parse(value as String);
  }
}
