import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';
import '../data/api_exceptions.dart';

/// API Service for REST communication with backend
/// All communication with backend goes through REST endpoints (not GraphQL mutations)
class ApiService {
  static ApiService? _instance;
  final FirebaseAuth _auth;

  ApiService._({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  /// Get base URL for API
  String get baseUrl {
    // Extract base from graphql endpoint
    final graphqlUrl = AppConstants.graphqlEndpoint;
    return graphqlUrl.replaceAll('/graphql', '');
  }

  /// Get authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final user = _auth.currentUser;
    String? token;
    if (user != null) {
      token = await user.getIdToken();
    }

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Generic GET request
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw NetworkException(message: ErrorMessages.connectionTimeout),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: ErrorMessages.getFriendlyMessage(e));
    }
  }

  /// Generic POST request
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders();
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw NetworkException(message: ErrorMessages.connectionTimeout),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: ErrorMessages.getFriendlyMessage(e));
    }
  }

  /// Generic PUT request
  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders();
      final response = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw NetworkException(message: ErrorMessages.connectionTimeout),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: ErrorMessages.getFriendlyMessage(e));
    }
  }

  /// Generic DELETE request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders();
      final response = await http.delete(uri, headers: headers).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw NetworkException(message: ErrorMessages.connectionTimeout),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: ErrorMessages.getFriendlyMessage(e));
    }
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else if (response.statusCode == 401) {
      throw UnauthorizedException(body['detail'] ?? 'Unauthorized');
    } else if (response.statusCode == 404) {
      throw NotFoundException(body['detail'] ?? 'Not found');
    } else {
      throw ApiException(body['detail'] ?? 'Server error');
    }
  }

  // ============================================
  // BOOKING API METHODS
  // ============================================

  /// Create a new booking request
  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> bookingData) async {
    return post('/api/bookings', bookingData);
  }

  /// Get booking by ID
  Future<Map<String, dynamic>> getBooking(String bookingId) async {
    return get('/api/bookings/$bookingId');
  }

  /// Get seeker's bookings
  Future<Map<String, dynamic>> getSeekerBookings({
    required String seekerId,
    String? status,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    return get('/api/bookings/seeker/$seekerId', queryParams: params);
  }

  /// Get seeker's active booking
  Future<Map<String, dynamic>> getSeekerActiveBooking(String seekerId) async {
    return get('/api/bookings/seeker/$seekerId/active');
  }

  /// Get provider's bookings
  Future<Map<String, dynamic>> getProviderBookings({
    required String providerId,
    String? status,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    return get('/api/bookings/provider/$providerId', queryParams: params);
  }

  /// Get provider's active booking
  Future<Map<String, dynamic>> getProviderActiveBooking(String providerId) async {
    return get('/api/bookings/provider/$providerId/active');
  }

  /// Get available bookings for providers
  Future<Map<String, dynamic>> getAvailableBookings({
    String? serviceType,
    double? latitude,
    double? longitude,
    double radiusKm = 50.0,
  }) async {
    final params = <String, String>{
      'radius_km': radiusKm.toString(),
    };
    if (serviceType != null) params['service_type'] = serviceType;
    if (latitude != null) params['latitude'] = latitude.toString();
    if (longitude != null) params['longitude'] = longitude.toString();
    return get('/api/bookings/available', queryParams: params);
  }

  /// Update booking status - provider arriving
  Future<Map<String, dynamic>> providerArriving(String bookingId, {int? estimatedMinutes}) async {
    final body = <String, dynamic>{};
    if (estimatedMinutes != null) body['estimatedMinutes'] = estimatedMinutes;
    return put('/api/bookings/$bookingId/arriving', body);
  }

  /// Update booking status - provider arrived
  Future<Map<String, dynamic>> providerArrived(String bookingId) async {
    return put('/api/bookings/$bookingId/arrived', {});
  }

  /// Start booking
  Future<Map<String, dynamic>> startBooking(String bookingId) async {
    return put('/api/bookings/$bookingId/start', {});
  }

  /// Complete booking
  Future<Map<String, dynamic>> completeBooking(String bookingId, {double? finalPrice}) async {
    final body = <String, dynamic>{};
    if (finalPrice != null) body['finalPrice'] = finalPrice;
    return put('/api/bookings/$bookingId/complete', body);
  }

  /// Cancel booking
  Future<Map<String, dynamic>> cancelBooking(String bookingId, {required String reason, String? cancelledBy}) async {
    return put('/api/bookings/$bookingId/cancel', {
      'reason': reason,
      if (cancelledBy != null) 'cancelledBy': cancelledBy,
    });
  }

  /// Rate a booking
  Future<Map<String, dynamic>> rateBooking(String bookingId, {required double rating, String? review}) async {
    return put('/api/bookings/$bookingId/rate', {
      'rating': rating,
      if (review != null) 'review': review,
    });
  }

  // ============================================
  // FARE OFFER API METHODS (InDrive-style bidding)
  // ============================================

  /// Create a fare offer (provider bids on booking)
  Future<Map<String, dynamic>> createFareOffer(Map<String, dynamic> offerData) async {
    return post('/api/fare-offers', offerData);
  }

  /// Get all offers for a booking (seeker views bids)
  Future<Map<String, dynamic>> getBookingOffers(String bookingId) async {
    return get('/api/fare-offers/booking/$bookingId');
  }

  /// Get provider's offers
  Future<Map<String, dynamic>> getProviderOffers(String providerId, {String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    return get('/api/fare-offers/provider/$providerId', queryParams: params);
  }

  /// Accept a fare offer
  Future<Map<String, dynamic>> acceptFareOffer(String offerId) async {
    return put('/api/fare-offers/$offerId/accept', {});
  }

  /// Reject a fare offer
  Future<Map<String, dynamic>> rejectFareOffer(String offerId) async {
    return put('/api/fare-offers/$offerId/reject', {});
  }

  /// Counter offer (seeker proposes different price)
  Future<Map<String, dynamic>> counterOffer(String offerId, double counterPrice) async {
    return put('/api/fare-offers/$offerId/counter', {
      'counterPrice': counterPrice,
    });
  }

  /// Update offer price (provider responds to counter)
  Future<Map<String, dynamic>> updateOfferPrice(String offerId, double newPrice, {String? message}) async {
    return put('/api/fare-offers/$offerId/update-price', {
      'newPrice': newPrice,
      'message': message,
    });
  }

  /// Withdraw offer
  Future<Map<String, dynamic>> withdrawOffer(String offerId) async {
    return put('/api/fare-offers/$offerId/withdraw', {});
  }

  // ============================================
  // SERVICE API METHODS
  // ============================================

  /// Get available services
  Future<Map<String, dynamic>> getAvailableServices({String? category}) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    return get('/api/services', queryParams: params);
  }

  /// Get provider's services
  Future<Map<String, dynamic>> getProviderServices(String providerId) async {
    return get('/api/services/provider/$providerId');
  }

  /// Create a service
  Future<Map<String, dynamic>> createService(Map<String, dynamic> serviceData) async {
    return post('/api/services', serviceData);
  }

  /// Update a service
  Future<Map<String, dynamic>> updateService(String serviceId, Map<String, dynamic> updateData) async {
    return put('/api/services/$serviceId', updateData);
  }

  /// Delete a service
  Future<Map<String, dynamic>> deleteService(String serviceId) async {
    return delete('/api/services/$serviceId');
  }

  // ============================================
  // VEHICLE API METHODS
  // ============================================

  /// Get provider's vehicles
  Future<Map<String, dynamic>> getProviderVehicles(String providerId) async {
    // This might need updating based on actual endpoint
    return get('/api/vehicles?provider_id=$providerId');
  }

  /// Create a vehicle
  Future<Map<String, dynamic>> createVehicle(Map<String, dynamic> vehicleData) async {
    return post('/api/vehicles', vehicleData);
  }

  /// Update a vehicle
  Future<Map<String, dynamic>> updateVehicle(String vehicleId, Map<String, dynamic> updateData) async {
    return put('/api/vehicles/$vehicleId', updateData);
  }

  /// Delete a vehicle
  Future<Map<String, dynamic>> deleteVehicle(String vehicleId) async {
    return delete('/api/vehicles/$vehicleId');
  }

  // ============================================
  // LOCATION API METHODS
  // ============================================

  /// Update location during active booking (real-time tracking)
  static Future<Map<String, dynamic>> updateBookingLocation({
    required String bookingId,
    required String userId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
  }) async {
    return instance.post('/api/locations/update', {
      'bookingId': bookingId,
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
      if (accuracy != null) 'accuracy': accuracy,
    });
  }

  /// Update user's general location (for providers)
  Future<Map<String, dynamic>> updateUserLocation(String userId, double latitude, double longitude) async {
    return post('/api/locations/user', {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Get booking locations (seeker and provider)
  Future<Map<String, dynamic>> getBookingLocations(String bookingId) async {
    return get('/api/locations/booking/$bookingId');
  }
  
  /// Get user's location for a specific booking
  Future<Map<String, dynamic>> getUserBookingLocation(String userId, String bookingId) async {
    return get('/api/locations/user/$userId/booking/$bookingId');
  }
}

/// API Exceptions
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(super.message);
}

class NotFoundException extends ApiException {
  NotFoundException(super.message);
}
