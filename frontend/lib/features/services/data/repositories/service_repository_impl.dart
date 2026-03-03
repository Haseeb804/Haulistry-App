import '../../domain/repositories/service_repository.dart';
import '../../domain/entities/service_entity.dart';
import '../datasources/service_remote_datasource.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/domain/entities/vehicle_entity.dart';

class ServiceRepositoryImpl implements ServiceRepository {
  final ServiceRemoteDataSource remoteDataSource;

  ServiceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ServiceEntity>> getAvailableServices({String? category}) async {
    try {
      return await remoteDataSource.getAvailableServices(category: category);
    } catch (e) {
      rethrow;
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
}
