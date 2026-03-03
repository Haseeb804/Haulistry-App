import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/data/graphql_client.dart';
import '../../../../core/data/api_exceptions.dart' as custom_exceptions;
import '../../../../core/domain/entities/vehicle_entity.dart';
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/domain/entities/service_entity.dart';
import '../../../../core/constants/app_constants.dart';

class ProviderRemoteDataSource {
  final GraphQLClientService graphQLClient;
  final String baseUrl = '${AppConstants.apiUrl}/api';

  ProviderRemoteDataSource({required this.graphQLClient});

  Future<List<VehicleEntity>> getProviderVehicles(String providerId) async {
    const String query = r'''
      query GetProviderVehicles($providerId: ID!) {
        getProviderVehicles(providerId: $providerId) {
          id
          providerId
          vehicleType
          vehicleNumber
          vehicleModel
          vehicleYear
          vehicleImageUrl
          vehicleImageBase64
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
          variables: {'providerId': providerId},
        ),
      );

      if (result.hasException) {
        throw _handleException(result.exception!);
      }

      final List<dynamic> vehicles = result.data?['getProviderVehicles'] ?? [];
      return vehicles.map((json) => VehicleEntity.fromJson(json)).toList();
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to fetch vehicles: $e');
    }
  }

  Future<VehicleEntity> createVehicle(Map<String, dynamic> vehicleData) async {
    try {
      
      // Check if image is too large
      if (vehicleData['vehicleImageBase64'] != null) {
        final imageSize = vehicleData['vehicleImageBase64'].length;
        if (imageSize > 5000000) { // ~5MB in base64
          throw custom_exceptions.ServerException(
            message: 'Image is too large. Please select a smaller image.',
          );
        }
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/vehicles'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(vehicleData),
      ).timeout(
        const Duration(seconds: 60), // Increased timeout to 60 seconds
        onTimeout: () {
          throw custom_exceptions.ServerException(
            message: 'Request timeout. Please check your internet connection and try again.',
          );
        },
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return VehicleEntity.fromJson(data['vehicle'] ?? data);
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to create vehicle',
        );
      }
    } on custom_exceptions.ApiException {
      rethrow;
    } catch (e) {
      throw custom_exceptions.ServerException(message: 'Failed to create vehicle: $e');
    }
  }

  Future<VehicleEntity> updateVehicle(String vehicleId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/vehicles/$vehicleId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return VehicleEntity.fromJson(data['vehicle'] ?? data);
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to update vehicle',
        );
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to update vehicle: $e');
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/vehicles/$vehicleId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to delete vehicle',
        );
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to delete vehicle: $e');
    }
  }

  Future<List<BookingEntity>> getProviderBookings(String providerId) async {
    const String query = r'''
      query GetUserBookings($userId: ID!) {
        getUserBookings(userId: $userId) {
          id
          seekerId
          seekerName
          providerId
          providerName
          vehicleId
          serviceType
          status
          pickupLatitude
          pickupLongitude
          pickupAddress
          dropLatitude
          dropLongitude
          dropAddress
          distanceInKm
          estimatedPrice
          finalPrice
          hours
          isUrgent
          scheduledDateTime
          startedAt
          completedAt
          cancelledAt
          cancellationReason
          notes
          rating
          review
          createdAt
          updatedAt
        }
      }
    ''';

    try {
      final result = await graphQLClient.query(
        QueryOptions(
          document: gql(query),
          variables: {'userId': providerId},
        ),
      );

      if (result.hasException) {
        throw _handleException(result.exception!);
      }

      final List<dynamic> bookings = result.data?['getUserBookings'] ?? [];
      return bookings.map((json) => BookingEntity.fromJson(json)).toList();
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to fetch bookings: $e');
    }
  }

  Future<BookingEntity> acceptBooking(String bookingId, String providerId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/bookings/$bookingId/accept?provider_id=$providerId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return BookingEntity.fromJson(data['booking'] ?? data);
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to accept booking',
        );
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to accept booking: $e');
    }
  }

  Future<BookingEntity> rejectBooking(String bookingId, String providerId, {String? reason}) async {
    try {
      final uri = Uri.parse('$baseUrl/bookings/$bookingId/reject?provider_id=$providerId${reason != null ? '&reason=$reason' : ''}');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return BookingEntity.fromJson(data['booking'] ?? data);
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to reject booking',
        );
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to reject booking: $e');
    }
  }

  Future<BookingEntity> completeBooking(String bookingId, {double? finalPrice}) async {
    try {
      final uri = finalPrice != null
          ? Uri.parse('$baseUrl/bookings/$bookingId/complete?final_price=$finalPrice')
          : Uri.parse('$baseUrl/bookings/$bookingId/complete');
      
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return BookingEntity.fromJson(data['booking'] ?? data);
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to complete booking',
        );
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to complete booking: $e');
    }
  }

  // ===== SERVICE CRUD METHODS =====

  Future<List<ServiceEntity>> getProviderServices(String providerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/services/provider/$providerId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> services = data['services'] ?? [];
        return services.map((json) => ServiceEntity.fromJson(json)).toList();
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to fetch services',
        );
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to fetch services: $e');
    }
  }

  Future<List<ServiceEntity>> getVehicleServices(String vehicleId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/services/vehicle/$vehicleId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> services = data['services'] ?? [];
        return services.map((json) => ServiceEntity.fromJson(json)).toList();
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to fetch vehicle services',
        );
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to fetch vehicle services: $e');
    }
  }

  Future<ServiceEntity> createService(Map<String, dynamic> serviceData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/services'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(serviceData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return ServiceEntity.fromJson(data['service'] ?? data);
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to create service',
        );
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to create service: $e');
    }
  }

  Future<ServiceEntity> updateService(String serviceId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/services/$serviceId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return ServiceEntity.fromJson(data['service'] ?? data);
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to update service',
        );
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to update service: $e');
    }
  }

  Future<void> deleteService(String serviceId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/services/$serviceId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to delete service',
        );
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to delete service: $e');
    }
  }

  custom_exceptions.ApiException _handleException(OperationException exception) {
    if (exception.linkException != null) {
      return custom_exceptions.NetworkException(message: 'Network error: ${exception.linkException}');
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

    return custom_exceptions.ServerException(message: 'Unknown error occurred');
  }
}
