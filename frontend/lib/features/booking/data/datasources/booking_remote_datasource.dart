import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/data/graphql_client.dart';
import '../../../../core/data/api_exceptions.dart' as custom_exceptions;
import '../../../../core/domain/entities/booking_entity.dart';
import '../../../../core/constants/app_constants.dart';

class BookingRemoteDataSource {
  final GraphQLClientService graphQLClient;
  final String baseUrl = '${AppConstants.apiUrl}/api';

  BookingRemoteDataSource({required this.graphQLClient});

  // REST API: Create booking (mutation)
  Future<BookingEntity> createBooking(Map<String, dynamic> bookingData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bookingData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return BookingEntity.fromJson(data['booking'] ?? data);
      } else {
        final error = json.decode(response.body);
        String errorMessage = 'Failed to create booking';
        
        // Handle validation errors (list of errors)
        if (error['detail'] is List) {
          final errors = error['detail'] as List;
          if (errors.isNotEmpty) {
            final firstError = errors[0];
            errorMessage = firstError['msg'] ?? errorMessage;
          }
        } else if (error['detail'] is String) {
          errorMessage = error['detail'];
        } else if (error['message'] != null) {
          errorMessage = error['message'];
        }
        
        throw custom_exceptions.ServerException(message: errorMessage);
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to create booking: $e');
    }
  }

  Future<List<BookingEntity>> getUserBookings(String userId) async {
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
          variables: {'userId': userId},
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

  Future<BookingEntity> getBookingById(String bookingId) async {
    const String query = r'''
      query GetBooking($id: ID!) {
        getBooking(id: $id) {
          id
          userId
          providerId
          serviceType
          pickupLocation
          dropoffLocation
          pickupLat
          pickupLng
          dropoffLat
          dropoffLng
          scheduledDate
          status
          estimatedPrice
          finalPrice
          distance
          createdAt
          updatedAt
        }
      }
    ''';

    try {
      final result = await graphQLClient.query(
        QueryOptions(
          document: gql(query),
          variables: {'id': bookingId},
        ),
      );

      if (result.hasException) {
        throw _handleException(result.exception!);
      }

      final data = result.data?['getBooking'];
      if (data == null) {
        throw custom_exceptions.NotFoundException(message: 'Booking not found');
      }

      return BookingEntity.fromJson(data);
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to fetch booking: $e');
    }
  }

  Future<BookingEntity> updateBookingStatus(String bookingId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/bookings/$bookingId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return BookingEntity.fromJson(data['booking'] ?? data);
      } else {
        final error = json.decode(response.body);
        throw custom_exceptions.ServerException(
          message: error['detail'] ?? 'Failed to update booking status',
        );
      }
    } catch (e) {
      if (e is custom_exceptions.ApiException) rethrow;
      throw custom_exceptions.ServerException(message: 'Failed to update booking status: $e');
    }
  }

  Future<BookingEntity> acceptBooking(String bookingId, String providerId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/bookings/$bookingId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'providerId': providerId}),
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

  Future<BookingEntity> completeBooking(String bookingId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/bookings/$bookingId/complete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({}),
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
