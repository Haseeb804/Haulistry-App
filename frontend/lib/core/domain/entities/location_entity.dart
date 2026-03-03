/// Location Entity - For real-time location tracking
class LocationEntity {
  final String userId;
  final String? bookingId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final DateTime updatedAt;

  const LocationEntity({
    required this.userId,
    this.bookingId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
    required this.updatedAt,
  });

  factory LocationEntity.fromJson(Map<String, dynamic> json) {
    return LocationEntity(
      userId: json['userId'] as String,
      bookingId: json['bookingId'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'bookingId': bookingId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  LocationEntity copyWith({
    String? userId,
    String? bookingId,
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
    double? accuracy,
    DateTime? updatedAt,
  }) {
    return LocationEntity(
      userId: userId ?? this.userId,
      bookingId: bookingId ?? this.bookingId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
