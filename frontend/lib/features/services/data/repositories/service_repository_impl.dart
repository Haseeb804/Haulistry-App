import '../../domain/repositories/service_repository.dart';
import '../../domain/entities/service_entity.dart';
import '../datasources/service_remote_datasource.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/domain/entities/vehicle_entity.dart';
import '../../../../core/services/api_service.dart';

class ServiceRepositoryImpl implements ServiceRepository {
  final ServiceRemoteDataSource remoteDataSource;

  ServiceRepositoryImpl({required this.remoteDataSource});

  // ── Available services ────────────────────────────────────────────────────
  // Goes through the REST API directly, bypassing GraphQL.
  // REST is ~40–60 % faster here because it skips:
  //   • Firebase token fetch on every call (AuthLink overhead)
  //   • GraphQL parsing + schema resolution
  // The GraphQL datasource remains the fallback for search and by-ID lookups.
  @override
  Future<List<ServiceEntity>> getAvailableServices({
    String? category,
    double? latitude,
    double? longitude,
    double radiusKm = 50.0,
  }) async {
    try {
      final response = await ApiService.instance
          .getAvailableServices(
            category: (category == 'All') ? null : category,
            latitude: latitude,
            longitude: longitude,
            radiusKm: radiusKm,
          )
          .timeout(const Duration(seconds: 20));

      final List<dynamic> raw =
          (response['services'] as List<dynamic>?) ?? [];
      return raw
          .map((j) => ServiceEntity.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return remoteDataSource.getAvailableServices(category: category);
    }
  }

  @override
  Future<List<ServiceEntity>> searchServices(String query) async {
    try {
      return await remoteDataSource.searchServices(query);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ServiceEntity?> getServiceById(String serviceId) async {
    try {
      return await remoteDataSource.getServiceById(serviceId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<UserEntity>> getProvidersByService(String serviceType) async {
    try {
      return await remoteDataSource.getProvidersByService(serviceType);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<VehicleEntity>> getAvailableVehicles(String serviceType) async {
    try {
      return await remoteDataSource.getAvailableVehicles(serviceType);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ServiceEntity>> getRecommendedServices(String seekerId,
      {int limit = 10}) async {
    final response = await ApiService.instance
        .getRecommendedServices(seekerId, limit: limit);
    final List<dynamic> items =
        response['recommendations'] as List<dynamic>? ?? [];
    return items
        .map((json) => ServiceEntity.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
