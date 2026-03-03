# Haulistry - Heavy Machinery & Transport Booking App

A comprehensive Flutter application for booking heavy machinery services including harvesters, sand trucks, brick trucks, and cranes.

## Features

### Service Seeker Features
- Browse available services by category
- View detailed service information
- Book services with date and time selection
- Track booking status
- Rate and review services
- Real-time chat with providers
- Notifications for booking updates

### Service Provider Features
- List multiple services
- Manage bookings
- Accept/reject booking requests
- Update service availability
- Track earnings
- Respond to customer inquiries

## Project Structure

```
lib/
├── main.dart
├── models/
│   ├── user_model.dart
│   ├── service_model.dart
│   └── booking_model.dart
├── providers/
│   ├── auth_provider.dart
│   ├── booking_provider.dart
│   └── theme_provider.dart
├── routes/
│   └── app_router.dart
├── screens/
│   ├── splash_screen.dart
│   ├── onboarding_screen.dart
│   ├── auth/
│   │   ├── role_selection_screen.dart
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   └── forgot_password_screen.dart
│   ├── seeker/
│   │   ├── seeker_dashboard_screen.dart
│   │   ├── service_listing_screen.dart
│   │   ├── service_detail_screen.dart
│   │   ├── booking_screen.dart
│   │   ├── my_bookings_screen.dart
│   │   ├── booking_detail_screen.dart
│   │   └── seeker_profile_screen.dart
│   ├── provider/
│   │   ├── provider_dashboard_screen.dart
│   │   ├── my_services_screen.dart
│   │   ├── add_service_screen.dart
│   │   ├── edit_service_screen.dart
│   │   ├── received_bookings_screen.dart
│   │   ├── booking_management_screen.dart
│   │   └── provider_profile_screen.dart
│   └── common/
│       ├── notifications_screen.dart
│       ├── messages_screen.dart
│       ├── chat_screen.dart
│       ├── settings_screen.dart
│       └── help_support_screen.dart
├── utils/
│   ├── app_colors.dart
│   └── app_constants.dart
└── widgets/
    └── custom_text_field.dart
```

## Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / VS Code
- Android Emulator / iOS Simulator / Physical Device

### Installation

1. Clone the repository
```bash
cd d:\FYP\Haulistry\haulistry_app
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
flutter run
```

## Key Dependencies

- **provider**: State management
- **go_router**: Navigation
- **google_fonts**: Custom fonts
- **shared_preferences**: Local storage
- **dio/http**: API calls
- **image_picker**: Image selection
- **geolocator**: Location services
- **google_maps_flutter**: Maps integration
- **flutter_rating_bar**: Rating widget
- **lottie**: Animations

## Color Scheme

- Primary: #2563EB (Blue)
- Secondary: #F59E0B (Amber)
- Accent: #10B981 (Green)
- Service Categories:
  - Harvester: #F59E0B
  - Sand Truck: #8B5CF6
  - Brick Truck: #EC4899
  - Crane: #06B6D4

## User Roles

1. **Service Seeker**: Users who want to book services
2. **Service Provider**: Users who offer services

## Screen Flow

### First Time User
1. Splash Screen → Onboarding → Role Selection → Signup → Dashboard

### Returning User
1. Splash Screen → Dashboard (based on role)

### Service Seeker Flow
1. Dashboard → Service Listing → Service Detail → Booking → My Bookings

### Service Provider Flow
1. Dashboard → My Services → Add/Edit Service → Received Bookings → Booking Management

## Implementation Status

### ✅ Completed
- Main app structure
- Routing setup
- State management (Providers)
- Models
- Splash screen
- Onboarding screen
- Role selection screen
- Login screen
- Custom widgets (TextField)
- Color scheme and constants

### 📝 To Be Implemented
- Signup screen
- Forgot password screen
- All dashboard screens
- Service listing and details
- Booking screens
- Profile screens
- Common screens (notifications, messages, chat)
- Settings screen
- Help & support screen
- API integration
- Image upload functionality
- Maps integration
- Payment integration

## Next Steps

1. **Create remaining authentication screens**:
   - Signup screen
   - Forgot password screen

2. **Implement dashboard screens**:
   - Seeker dashboard with service categories
   - Provider dashboard with statistics

3. **Build service screens**:
   - Service listing with filters
   - Service detail with booking button
   - Add/edit service forms

4. **Create booking system**:
   - Booking form with date/time picker
   - Booking list and details
   - Booking management for providers

5. **Add communication features**:
   - Notifications list
   - Messages/chat interface

6. **Implement profile screens**:
   - View and edit profile
   - Settings and preferences

7. **Backend Integration**:
   - Connect to REST API
   - Handle authentication tokens
   - Implement error handling

8. **Testing**:
   - Unit tests
   - Widget tests
   - Integration tests

## API Endpoints (To be implemented)

```
POST   /auth/register
POST   /auth/login
POST   /auth/forgot-password
GET    /services?type={type}
GET    /services/{id}
POST   /services
PUT    /services/{id}
DELETE /services/{id}
GET    /bookings
POST   /bookings
PUT    /bookings/{id}
GET    /notifications
GET    /messages
POST   /messages
```

## Contributing

1. Create feature branch
2. Implement changes
3. Test thoroughly
4. Submit for review

## License

This project is part of a Final Year Project (FYP) for educational purposes.

## Contact

For any queries regarding this project, please contact the development team.
