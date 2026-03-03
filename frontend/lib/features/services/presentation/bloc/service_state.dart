import 'package:equatable/equatable.dart';
import '../../domain/entities/service_entity.dart';

abstract class ServiceState extends Equatable {
  const ServiceState();

  @override
  List<Object?> get props => [];
}

class ServiceInitial extends ServiceState {
  const ServiceInitial();
}

class ServiceLoading extends ServiceState {
  const ServiceLoading();
}

class ServiceLoaded extends ServiceState {
  final List<ServiceEntity> services;
  final String? selectedCategory;

  const ServiceLoaded({
    required this.services,
    this.selectedCategory,
  });

  @override
  List<Object?> get props => [services, selectedCategory];
}

class ServiceError extends ServiceState {
  final String message;

  const ServiceError({required this.message});

  @override
  List<Object?> get props => [message];
}
