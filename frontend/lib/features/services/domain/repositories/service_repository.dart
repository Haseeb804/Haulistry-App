import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/domain/entities/vehicle_entity.dart';
import '../entities/service_entity.dart';

abstract class ServiceRepository {
  /// Get all active services from verified providers
  Future<List<ServiceEntity>> getAvailableServices({String? category});
  
  /// Search services by query
  Future<List<ServiceEntity>> searchServices(String query);
  
  /// Get service by ID
  Future<ServiceEntity?> getServiceById(String serviceId);
  
  /// Get providers offering a specific service type
  Future<List<UserEntity>> getProvidersByService(String serviceType);
  
  /// Get available vehicles for a service type
  Future<List<VehicleEntity>> getAvailableVehicles(String serviceType);

  /// Get personalized recommended services for a seeker
  Future<List<ServiceEntity>> getRecommendedServices(String seekerId, {int limit = 10});
}
