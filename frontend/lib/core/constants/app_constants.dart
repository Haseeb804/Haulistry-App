/// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Haulistry';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String apiUrl = 'https://haulistry-app.vercel.app';
  static const String graphqlEndpoint = 'https://haulistry-app.vercel.app/graphql';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String servicesCollection = 'services';
  static const String bookingsCollection = 'bookings';
  
  // User Roles
  static const String roleSeeker = 'seeker';
  static const String roleProvider = 'provider';
  static const String roleUser = 'user';
  
  // Service Categories (for service offerings)
  static const List<String> serviceTypes = [
    'Sand Trolley',
    'Bricks Trolley',
    'Harvester',
    'Crane',
    'Tractor',
    'Loader',
    'Dumper',
    'Excavator',
    'Concrete Mixer',
    'Water Tanker',
    'Other',
  ];
  
  // Vehicle/Equipment Types (for registration)
  static const List<String> vehicleTypes = [
    'Trolley',
    'Tractor',
    'Harvester',
    'Crane',
    'Loader',
    'Dumper',
    'Excavator',
    'Concrete Mixer',
    'Water Tanker',
    'Truck',
    'Other',
  ];
  
  // Booking Status
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusActive = 'active';
  static const String statusProviderArriving = 'provider_arriving';
  static const String statusProviderArrived = 'provider_arrived';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  static const String statusRejected = 'rejected';
  static const String statusConfirmed = 'confirmed';
  static const String callTypeVoice = 'voice';
  static const String callTypeVideo = 'video';
  static const String callStatusRejected = 'rejected';
  static const String callStatusMissed = 'missed';
  static const String callStatusEnded = 'ended';

  static const Set<String> activeServiceStatuses = {
    statusConfirmed,
    statusAccepted,
    statusActive,
    statusProviderArriving,
    statusProviderArrived,
    statusInProgress,
  };

  static const Set<String> trackingStatuses = {
    statusAccepted,
    statusActive,
    statusProviderArriving,
    statusProviderArrived,
    statusInProgress,
  };

  // Route patterns
  static const String routeSeekerTrackingPattern = '/booking/:id/tracking';
  static const String routeSeekerAcceptedPattern = '/booking/:id/accepted';
  static const String routeProviderTrackingPattern = '/provider/tracking/:id';
  static const String routeLegacyTrackingPattern = '/tracking/:bookingId';

  static String seekerTrackingPath(String bookingId) => '/booking/$bookingId/tracking';
  static String seekerAcceptedPath(String bookingId) => '/booking/$bookingId/accepted';
  static String providerTrackingPath(String bookingId) => '/provider/tracking/$bookingId';
  static String legacyTrackingPath(String bookingId) => '/tracking/$bookingId';
  
  // Pricing Configuration
  static const Map<String, double> baseRates = {
    'Sand Trolley': 50.0,
    'Bricks Trolley': 60.0,
    'Harvester': 150.0,
    'Crane': 200.0,
    'Tractor': 100.0,
    'Loader': 120.0,
    'Dumper': 100.0,
    'Excavator': 180.0,
    'Concrete Mixer': 80.0,
    'Water Tanker': 70.0,
    'Other': 50.0,
  };
  
  static const double pricePerKm = 5.0;
  static const double minimumCharge = 100.0;
  
  // Map Configuration
  static const double defaultLatitude = 31.5204;
  static const double defaultLongitude = 74.3587; // Lahore, Pakistan
  static const double defaultZoom = 12.0;
  
  // Storage Keys
  static const String keyUserToken = 'user_token';
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyIsLoggedIn = 'is_logged_in';
  
  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 32;
  static const String phonePattern = r'^[0-9]{11}$';
  static const String cnicPattern = r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$';
}

class AppRoutes {
  // Auth
  static const String login = '/login';
  static const String signup = '/signup';
  static const String phoneAuth = '/phone-auth';
  static const String forgotPassword = '/forgot-password';

  // Service + booking
  static const String serviceByTypePattern = '/service/:serviceType';
  static const String bookingCreate = '/booking/create';
  static const String bookingConfirm = '/booking/confirm';
  static const String bookingStatusPattern = '/booking/:id/status';

  // Seeker
  static const String seekerHome = '/seeker/home';
  static const String seekerHistory = '/seeker/history';

  // Provider
  static const String providerDocuments = '/provider/documents';
  static const String providerHome = '/provider/home';
  static const String providerVehicles = '/provider/vehicles';
  static const String providerServices = '/provider/services';
  static const String providerEarnings = '/provider/earnings';
  static const String providerHistory = '/provider/history';
  static const String providerBookingPattern = '/provider/booking/:id';
  static const String providerRequestPattern = '/provider/request/:id';

  // Profile
  static const String profile = '/profile';
  static const String profileEdit = '/profile/edit';

  // Chat
  static const String chatList = '/chat';
  static const String chatPattern = '/chat/:conversationId';

  // Calls
  static const String callIncoming = '/call/incoming';
  static const String callOutgoing = '/call/outgoing';
  static const String callVoice = '/call/voice';
  static const String callVideo = '/call/video';

  // Feedback
  static const String feedbackSeeker = '/feedback/seeker';
  static const String feedbackProvider = '/feedback/provider';

  static String serviceByType(String serviceType) => '/service/$serviceType';
  static String bookingStatus(String bookingId) => '/booking/$bookingId/status';
  static String seekerTracking(String bookingId) => '/booking/$bookingId/tracking';
  static String seekerAccepted(String bookingId) => '/booking/$bookingId/accepted';
  static String providerTracking(String bookingId) => '/provider/tracking/$bookingId';
  static String providerBooking(String bookingId) => '/provider/booking/$bookingId';
  static String providerRequest(String bookingId) => '/provider/request/$bookingId';
  static String legacyTracking(String bookingId) => '/tracking/$bookingId';
  static String chat(String conversationId) => '/chat/$conversationId';
}

class ApiEndpoints {
  static const String bookings = '/api/bookings';
  static String bookingById(String bookingId) => '/api/bookings/$bookingId';
  static String seekerBookings(String seekerId) => '/api/bookings/seeker/$seekerId';
  static String seekerActiveBooking(String seekerId) => '/api/bookings/seeker/$seekerId/active';
  static String providerBookings(String providerId) => '/api/bookings/provider/$providerId';
  static String providerActiveBooking(String providerId) => '/api/bookings/provider/$providerId/active';
  static const String availableBookings = '/api/bookings/available';
  static String bookingArriving(String bookingId) => '/api/bookings/$bookingId/arriving';
  static String bookingArrived(String bookingId) => '/api/bookings/$bookingId/arrived';
  static String bookingStart(String bookingId) => '/api/bookings/$bookingId/start';
  static String bookingComplete(String bookingId) => '/api/bookings/$bookingId/complete';
  static String bookingCancel(String bookingId) => '/api/bookings/$bookingId/cancel';
  static String bookingRate(String bookingId) => '/api/bookings/$bookingId/rate';

  static const String fareOffers = '/api/fare-offers';
  static String bookingOffers(String bookingId) => '/api/fare-offers/booking/$bookingId';
  static String providerOffers(String providerId) => '/api/fare-offers/provider/$providerId';
  static String fareOfferById(String offerId) => '/api/fare-offers/$offerId';
  static String fareOfferAccept(String offerId) => '/api/fare-offers/$offerId/accept';
  static String fareOfferReject(String offerId) => '/api/fare-offers/$offerId/reject';
  static String fareOfferCounter(String offerId) => '/api/fare-offers/$offerId/counter';
  static String fareOfferUpdatePrice(String offerId) => '/api/fare-offers/$offerId/update-price';
  static String fareOfferWithdraw(String offerId) => '/api/fare-offers/$offerId/withdraw';

  static const String services = '/api/services';
  static String providerServices(String providerId) => '/api/services/provider/$providerId';
  static String serviceById(String serviceId) => '/api/services/$serviceId';

  static const String vehicles = '/api/vehicles';
  static String vehicleById(String vehicleId) => '/api/vehicles/$vehicleId';

  static const String locationUpdate = '/api/locations/update';
  static const String userLocationUpdate = '/api/locations/user';
  static String bookingLocations(String bookingId) => '/api/locations/booking/$bookingId';
  static String userBookingLocation(String userId, String bookingId) =>
      '/api/locations/user/$userId/booking/$bookingId';

  static const String callInitiate = '/api/calls/initiate';
  static const String callUpdateStatus = '/api/calls/update-status';
  static String callById(String callId) => '/api/calls/$callId';

  static const String messageSend = '/api/messages/send';
  static String conversationMessages(String user1Id, String user2Id, String bookingId) =>
      '/api/messages/conversation/$user1Id/$user2Id/$bookingId';

  static const String feedbackProvider = '/api/feedback/provider';
  static const String feedbackSeeker = '/api/feedback/seeker';
  static String providerFeedbacks(String providerId) => '/api/feedback/provider/$providerId';
  static String seekerFeedbacks(String seekerId) => '/api/feedback/seeker/$seekerId';
  static String feedbackExists(String bookingId, String reviewerType) =>
      '/api/feedback/check/$bookingId/$reviewerType';
}

class MapEndpoints {
  static const String osmTileTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String nominatimReverse = 'https://nominatim.openstreetmap.org/reverse';
  static const String nominatimSearch = 'https://nominatim.openstreetmap.org/search';
  static const String osrmRouteBase = 'https://router.project-osrm.org/route/v1/driving';
  static const String userAgent = 'Haulistry Mobile App';
}
