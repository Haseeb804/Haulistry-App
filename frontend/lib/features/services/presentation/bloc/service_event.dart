import 'package:equatable/equatable.dart';

abstract class ServiceEvent extends Equatable {
  const ServiceEvent();

  @override
  List<Object?> get props => [];
}

class ServiceLoadRequested extends ServiceEvent {
  final double? latitude;
  final double? longitude;
  final double radiusKm;

  const ServiceLoadRequested({
    this.latitude,
    this.longitude,
    this.radiusKm = 50.0,
  });

  @override
  List<Object?> get props => [latitude, longitude, radiusKm];
}

class ServiceSearchRequested extends ServiceEvent {
  final String query;

  const ServiceSearchRequested({required this.query});

  @override
  List<Object?> get props => [query];
}

class ServiceFilterByCategory extends ServiceEvent {
  final String category;
  final double? latitude;
  final double? longitude;
  final double radiusKm;

  const ServiceFilterByCategory({
    required this.category,
    this.latitude,
    this.longitude,
    this.radiusKm = 50.0,
  });

  @override
  List<Object?> get props => [category, latitude, longitude, radiusKm];
}

class ServiceLoadRecommendationsRequested extends ServiceEvent {
  final String seekerId;

  const ServiceLoadRecommendationsRequested({required this.seekerId});

  @override
  List<Object?> get props => [seekerId];
}
