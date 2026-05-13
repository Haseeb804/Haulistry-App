import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/service_repository.dart';
import 'service_event.dart';
import 'service_state.dart';

class ServiceBloc extends Bloc<ServiceEvent, ServiceState> {
  final ServiceRepository repository;

  ServiceBloc({required this.repository}) : super(const ServiceInitial()) {
    on<ServiceLoadRequested>(_onServiceLoadRequested);
    on<ServiceSearchRequested>(_onServiceSearchRequested);
    on<ServiceFilterByCategory>(_onServiceFilterByCategory);
    on<ServiceLoadRecommendationsRequested>(_onLoadRecommendationsRequested);
  }

  Future<void> _onServiceLoadRequested(
    ServiceLoadRequested event,
    Emitter<ServiceState> emit,
  ) async {
    emit(const ServiceLoading());
    try {
      final services = await repository.getAvailableServices();
      emit(ServiceLoaded(services: services));
    } catch (e) {
      emit(ServiceError(message: e.toString()));
    }
  }

  Future<void> _onServiceSearchRequested(
    ServiceSearchRequested event,
    Emitter<ServiceState> emit,
  ) async {
    emit(const ServiceLoading());
    try {
      final services = await repository.searchServices(event.query);
      emit(ServiceLoaded(services: services));
    } catch (e) {
      emit(ServiceError(message: e.toString()));
    }
  }

  Future<void> _onServiceFilterByCategory(
    ServiceFilterByCategory event,
    Emitter<ServiceState> emit,
  ) async {
    emit(const ServiceLoading());
    try {
      final services = event.category == 'All'
          ? await repository.getAvailableServices()
          : await repository.getAvailableServices(category: event.category);

      emit(ServiceLoaded(
        services: services,
        selectedCategory: event.category,
      ));
    } catch (e) {
      emit(ServiceError(message: e.toString()));
    }
  }

  Future<void> _onLoadRecommendationsRequested(
    ServiceLoadRecommendationsRequested event,
    Emitter<ServiceState> emit,
  ) async {
    try {
      final recs = await repository.getRecommendedServices(event.seekerId);
      emit(ServiceRecommendationsLoaded(recommendations: recs));
    } catch (_) {
      // Recommendations are non-critical — silently fail and keep current state.
    }
  }
}
