/// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Haulistry';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String apiUrl = 'https://haulistry-app.vercel.app';
  static const String graphqlEndpoint = 'https://haulistry-app.vercel.app/graphql';
  static const String wsEndpoint = 'wss://haulistry-app.vercel.app/ws';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String servicesCollection = 'services';
  static const String bookingsCollection = 'bookings';
  
  // User Roles
  static const String roleSeeker = 'seeker';
  static const String roleProvider = 'provider';
  
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
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  
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
