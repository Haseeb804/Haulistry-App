import 'dart:convert';
import 'dart:typed_data';
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

  /// Multipart POST request (e.g., image/audio uploads)
  /// Note: Filename extension is used by HTTP client for MIME type auto-detection
  Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    required String fileField,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);

      final user = _auth.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }

      request.fields.addAll(fields);
      
      // HTTP client auto-detects MIME type from filename extension
      // This works because we detect image format from bytes and generate
      // audio files with proper extensions
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw NetworkException(message: ErrorMessages.connectionTimeout),
      );

      final response = await http.Response.fromStream(streamedResponse);
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
    return post(ApiEndpoints.bookings, bookingData);
  }

  /// Get booking by ID
  Future<Map<String, dynamic>> getBooking(String bookingId) async {
    return get(ApiEndpoints.bookingById(bookingId));
  }

  /// Get seeker's bookings
  Future<Map<String, dynamic>> getSeekerBookings({
    required String seekerId,
    String? status,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    return get(ApiEndpoints.seekerBookings(seekerId), queryParams: params);
  }

  /// Get seeker's active booking
  Future<Map<String, dynamic>> getSeekerActiveBooking(String seekerId) async {
    return get(ApiEndpoints.seekerActiveBooking(seekerId));
  }

  /// Get provider's bookings
  Future<Map<String, dynamic>> getProviderBookings({
    required String providerId,
    String? status,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    return get(ApiEndpoints.providerBookings(providerId), queryParams: params);
  }

  /// Get provider's active booking
  Future<Map<String, dynamic>> getProviderActiveBooking(String providerId) async {
    return get(ApiEndpoints.providerActiveBooking(providerId));
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
    return get(ApiEndpoints.availableBookings, queryParams: params);
  }

  /// Update booking status - provider arriving
  Future<Map<String, dynamic>> providerArriving(String bookingId, {int? estimatedMinutes}) async {
    final body = <String, dynamic>{};
    if (estimatedMinutes != null) body['estimatedMinutes'] = estimatedMinutes;
    return put(ApiEndpoints.bookingArriving(bookingId), body);
  }

  /// Update booking status - provider arrived
  Future<Map<String, dynamic>> providerArrived(String bookingId) async {
    return put(ApiEndpoints.bookingArrived(bookingId), {});
  }

  /// Start booking
  Future<Map<String, dynamic>> startBooking(String bookingId) async {
    return put(ApiEndpoints.bookingStart(bookingId), {});
  }

  /// Complete booking
  Future<Map<String, dynamic>> completeBooking(String bookingId, {double? finalPrice}) async {
    final body = <String, dynamic>{};
    if (finalPrice != null) body['finalPrice'] = finalPrice;
    return put(ApiEndpoints.bookingComplete(bookingId), body);
  }

  /// Cancel booking
  Future<Map<String, dynamic>> cancelBooking(String bookingId, {required String reason, String? cancelledBy}) async {
    return put(ApiEndpoints.bookingCancel(bookingId), {
      'reason': reason,
      if (cancelledBy != null) 'cancelledBy': cancelledBy,
    });
  }

  /// Rate a booking
  Future<Map<String, dynamic>> rateBooking(String bookingId, {required double rating, String? review}) async {
    return put(ApiEndpoints.bookingRate(bookingId), {
      'rating': rating,
      if (review != null) 'review': review,
    });
  }

  // ============================================
  // FARE OFFER API METHODS (InDrive-style bidding)
  // ============================================

  /// Create a fare offer (provider bids on booking)
  Future<Map<String, dynamic>> createFareOffer(Map<String, dynamic> offerData) async {
    return post(ApiEndpoints.fareOffers, offerData);
  }

  /// Get all offers for a booking (seeker views bids)
  Future<Map<String, dynamic>> getBookingOffers(String bookingId) async {
    return get(ApiEndpoints.bookingOffers(bookingId));
  }

  /// Get provider's offers
  Future<Map<String, dynamic>> getProviderOffers(String providerId, {String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    return get(ApiEndpoints.providerOffers(providerId), queryParams: params);
  }

  /// Accept a fare offer
  Future<Map<String, dynamic>> acceptFareOffer(String offerId) async {
    return put(ApiEndpoints.fareOfferAccept(offerId), {});
  }

  /// Reject a fare offer
  Future<Map<String, dynamic>> rejectFareOffer(String offerId) async {
    return put(ApiEndpoints.fareOfferReject(offerId), {});
  }

  /// Counter offer (seeker proposes different price)
  Future<Map<String, dynamic>> counterOffer(String offerId, double counterPrice) async {
    return put(ApiEndpoints.fareOfferCounter(offerId), {
      'counterPrice': counterPrice,
    });
  }

  /// Update offer price (provider responds to counter)
  Future<Map<String, dynamic>> updateOfferPrice(String offerId, double newPrice, {String? message}) async {
    return put(ApiEndpoints.fareOfferUpdatePrice(offerId), {
      'newPrice': newPrice,
      'message': message,
    });
  }

  /// Withdraw offer
  Future<Map<String, dynamic>> withdrawOffer(String offerId) async {
    return put(ApiEndpoints.fareOfferWithdraw(offerId), {});
  }

  // ============================================
  // SERVICE API METHODS
  // ============================================

  /// Get available services
  Future<Map<String, dynamic>> getAvailableServices({
    String? category,
    double? latitude,
    double? longitude,
    double radiusKm = 50.0,
  }) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (latitude != null) params['latitude'] = latitude.toString();
    if (longitude != null) params['longitude'] = longitude.toString();
    if (latitude != null || longitude != null) params['radius'] = radiusKm.toString();
    return get(ApiEndpoints.services, queryParams: params.isEmpty ? null : params);
  }

  /// Get provider's services
  Future<Map<String, dynamic>> getProviderServices(String providerId) async {
    return get(ApiEndpoints.providerServices(providerId));
  }

  /// Create a service
  Future<Map<String, dynamic>> createService(Map<String, dynamic> serviceData) async {
    return post(ApiEndpoints.services, serviceData);
  }

  /// Update a service
  Future<Map<String, dynamic>> updateService(String serviceId, Map<String, dynamic> updateData) async {
    return put(ApiEndpoints.serviceById(serviceId), updateData);
  }

  /// Delete a service
  Future<Map<String, dynamic>> deleteService(String serviceId) async {
    return delete(ApiEndpoints.serviceById(serviceId));
  }

  // ============================================
  // RECOMMENDATIONS API METHODS
  // ============================================

  /// Get personalized service recommendations for a seeker
  Future<Map<String, dynamic>> getRecommendedServices(
    String seekerId, {
    int limit = 10,
    double? latitude,
    double? longitude,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (latitude != null) params['latitude'] = latitude.toString();
    if (longitude != null) params['longitude'] = longitude.toString();
    return get(ApiEndpoints.recommendations(seekerId), queryParams: params);
  }

  /// Update a seeker's interest list
  Future<Map<String, dynamic>> updateSeekerInterests(String seekerId, List<String> interests) async {
    return put(ApiEndpoints.seekerInterests(seekerId), {'interests': interests});
  }

  /// Get a seeker's interest list
  Future<Map<String, dynamic>> getSeekerInterests(String seekerId) async {
    return get(ApiEndpoints.seekerInterests(seekerId));
  }

  /// Get all verified providers (excluding self) for the Providers Explorer
  Future<Map<String, dynamic>> exploreProviders({
    String requesterId = '',
    int limit = 50,
    int offset = 0,
  }) async {
    return get(ApiEndpoints.providersExplore, queryParams: {
      'requester_id': requesterId,
      'limit': limit.toString(),
      'offset': offset.toString(),
    }).timeout(const Duration(seconds: 25));
  }

  // ============================================
  // VEHICLE API METHODS
  // ============================================

  /// Get provider's vehicles
  Future<Map<String, dynamic>> getProviderVehicles(String providerId) async {
    // This might need updating based on actual endpoint
    return get(ApiEndpoints.vehicles, queryParams: {'provider_id': providerId});
  }

  /// Create a vehicle
  Future<Map<String, dynamic>> createVehicle(Map<String, dynamic> vehicleData) async {
    return post(ApiEndpoints.vehicles, vehicleData);
  }

  /// Update a vehicle
  Future<Map<String, dynamic>> updateVehicle(String vehicleId, Map<String, dynamic> updateData) async {
    return put(ApiEndpoints.vehicleById(vehicleId), updateData);
  }

  /// Delete a vehicle
  Future<Map<String, dynamic>> deleteVehicle(String vehicleId) async {
    return delete(ApiEndpoints.vehicleById(vehicleId));
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
    return instance.post(ApiEndpoints.locationUpdate, {
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
    return post(ApiEndpoints.userLocationUpdate, {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Get booking locations (seeker and provider)
  Future<Map<String, dynamic>> getBookingLocations(String bookingId) async {
    return get(ApiEndpoints.bookingLocations(bookingId));
  }
  
  /// Get user's location for a specific booking
  Future<Map<String, dynamic>> getUserBookingLocation(String userId, String bookingId) async {
    return get(ApiEndpoints.userBookingLocation(userId, bookingId));
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
