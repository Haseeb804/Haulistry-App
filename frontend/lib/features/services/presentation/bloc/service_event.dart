import 'package:equatable/equatable.dart';

abstract class ServiceEvent extends Equatable {
  const ServiceEvent();

  @override
  List<Object?> get props => [];
}

class ServiceLoadRequested extends ServiceEvent {
  const ServiceLoadRequested();
}

class ServiceSearchRequested extends ServiceEvent {
  final String query;

  const ServiceSearchRequested({required this.query});

  @override
  List<Object?> get props => [query];
}

class ServiceFilterByCategory extends ServiceEvent {
  final String category;

  const ServiceFilterByCategory({required this.category});

  @override
  List<Object?> get props => [category];
}

class ServiceLoadRecommendationsRequested extends ServiceEvent {
  final String seekerId;

  const ServiceLoadRecommendationsRequested({required this.seekerId});

  @override
  List<Object?> get props => [seekerId];
}
