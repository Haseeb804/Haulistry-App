import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../../core/data/graphql_client.dart';
import '../../../../core/data/api_exceptions.dart' as custom_exceptions;
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/domain/entities/vehicle_entity.dart';
import '../../domain/entities/service_entity.dart';

class ServiceRemoteDataSource {
  final GraphQLClientService graphQLClient;

  ServiceRemoteDataSource({required this.graphQLClient});

  /// Get all available services from verified providers
  Future<List<ServiceEntity>> getAvailableServices({String? category}) async {
    const String query = r'''
      query GetAvailableServices($category: String) {
        getAvailableServices(category: $category) {
          id
          providerId
          vehicleId
          name
          description
          imageUrl
          basePrice
          pricePerKm
          pricePerHour
          category
          isActive
          providerName
          providerRating
          providerLatitude
          providerLongitude
          providerImageUrl
          vehicleType
          vehicleNumber
          vehicleImageBase64
          createdAt
          updatedAt
        }
      }
    ''';

    try {
      final result = await graphQLClient.query(
        QueryOptions(
          document: gql(query),
          variables: {'category': category},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        throw _handleException(result.exception!);
      }

      final List<dynamic> services = result.data?['getAvailableServices'] ?? [];
      return services.map((json) => ServiceEntity.fromJson(json)).toList();
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to fetch services: $e');
    }
  }

  /// Search services by query
  Future<List<ServiceEntity>> searchServices(String query) async {
    const String gqlQuery = r'''
      query SearchServices($query: String!) {
        searchServices(query: $query) {
          id
          providerId
          vehicleId
          name
          description
          imageUrl
          basePrice
          pricePerKm
          pricePerHour
          category
          isActive
          providerName
          providerRating
          providerLatitude
          providerLongitude
          providerImageUrl
          vehicleType
          vehicleNumber
          vehicleImageBase64
          createdAt
          updatedAt
        }
      }
    ''';

    try {
      final result = await graphQLClient.query(
        QueryOptions(
          document: gql(gqlQuery),
          variables: {'query': query},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        throw _handleException(result.exception!);
      }

      final List<dynamic> services = result.data?['searchServices'] ?? [];
      return services.map((json) => ServiceEntity.fromJson(json)).toList();
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to search services: $e');
    }
  }

  /// Get service by ID
  Future<ServiceEntity?> getServiceById(String serviceId) async {
    const String query = r'''
      query GetServiceById($serviceId: String!) {
        getServiceById(serviceId: $serviceId) {
          id
          providerId
          vehicleId
          name
          description
          imageUrl
          basePrice
          pricePerKm
          pricePerHour
          category
          isActive
          providerName
          providerRating
          providerLatitude
          providerLongitude
          providerImageUrl
          vehicleType
          vehicleNumber
          vehicleImageBase64
          createdAt
          updatedAt
        }
      }
    ''';

    try {
      final result = await graphQLClient.query(
        QueryOptions(
          document: gql(query),
          variables: {'serviceId': serviceId},
        ),
      );

      if (result.hasException) {
        throw _handleException(result.exception!);
      }

      final data = result.data?['getServiceById'];
      if (data == null) return null;
      return ServiceEntity.fromJson(data);
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to fetch service: $e');
    }
  }

  Future<List<UserEntity>> getProvidersByService(String serviceType) async {
    const String query = r'''
      query GetProvidersByService($serviceType: String!) {
        getProvidersByService(serviceType: $serviceType) {
          id
          name
          email
          role
          phone
          address
          profileImageUrl
          rating
          completedBookings
          isActive
          isVerified
          createdAt
          updatedAt
        }
      }
    ''';

    try {
      final result = await graphQLClient.query(
        QueryOptions(
          document: gql(query),
          variables: {'serviceType': serviceType},
        ),
      );

      if (result.hasException) {
        throw _handleException(result.exception!);
      }

      final List<dynamic> providers =
          result.data?['getProvidersByService'] ?? [];
      return providers.map((json) => UserEntity.fromJson(json)).toList();
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to fetch providers: $e');
    }
  }

  Future<List<VehicleEntity>> getAvailableVehicles(String serviceType) async {
    const String query = r'''
      query GetAvailableVehicles($serviceType: String!) {
        getAvailableVehicles(serviceType: $serviceType) {
          id
          providerId
          vehicleType
          vehicleNumber
          vehicleModel
          vehicleYear
          vehicleImageUrl
          isAvailable
          capacity
          createdAt
          updatedAt
        }
      }
    ''';

    try {
      final result = await graphQLClient.query(
        QueryOptions(
          document: gql(query),
          variables: {'serviceType': serviceType},
        ),
      );

      if (result.hasException) {
        throw _handleException(result.exception!);
      }

      final List<dynamic> vehicles =
          result.data?['getAvailableVehicles'] ?? [];
      return vehicles.map((json) => VehicleEntity.fromJson(json)).toList();
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to fetch vehicles: $e');
    }
  }

  custom_exceptions.ApiException _handleException(OperationException exception) {
    if (exception.linkException != null) {
      final errorStr = exception.linkException.toString().toLowerCase();
      if (errorStr.contains('socketexception') ||
          errorStr.contains('connection refused') ||
          errorStr.contains('network is unreachable') ||
          errorStr.contains('no address associated')) {
        return custom_exceptions.NetworkException(
            message: 'Please check your internet connection and try again');
      }
      return custom_exceptions.NetworkException(
          message: 'Please check your internet connection and try again');
    }

    final errors = exception.graphqlErrors;
    if (errors.isNotEmpty) {
      final error = errors.first;
      final message = error.message;

      if (message.toLowerCase().contains('unauthorized')) {
        return custom_exceptions.UnauthorizedException(message: message);
      } else if (message.toLowerCase().contains('not found')) {
        return custom_exceptions.NotFoundException(message: message);
      } else {
        return custom_exceptions.ServerException(message: message);
      }
    }

    return custom_exceptions.ServerException(message: 'Something went wrong. Please try again later');
  }
}
