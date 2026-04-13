import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/services/notification_service.dart';
import 'core/data/graphql_client.dart';
import 'features/auth/data/repository/auth_repository_impl.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/signup_screen.dart';
import 'features/auth/presentation/screens/phone_auth_screen.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/services/presentation/screens/seeker_home_screen.dart';
import 'features/services/presentation/screens/service_detail_screen.dart';
import 'features/services/presentation/bloc/service_bloc.dart';
import 'features/services/presentation/bloc/service_event.dart';
import 'features/services/data/datasources/service_remote_datasource.dart';
import 'features/services/data/repositories/service_repository_impl.dart';
import 'features/services/domain/entities/service_entity.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/profile/presentation/screens/edit_profile_screen.dart';
import 'features/provider/presentation/screens/provider_documents_screen.dart';
import 'features/provider/presentation/screens/provider_home_screen.dart';
import 'features/provider/presentation/screens/vehicle_management_screen.dart';
import 'features/provider/presentation/screens/service_management_screen.dart';
import 'features/provider/presentation/screens/earnings_dashboard_screen.dart';
import 'features/provider/presentation/bloc/provider_bloc.dart';
import 'features/provider/data/datasources/provider_remote_datasource.dart';
import 'features/provider/data/repositories/provider_repository_impl.dart';
import 'features/booking/presentation/bloc/booking_bloc.dart';
import 'features/booking/presentation/bloc/negotiation_bloc.dart';
import 'features/booking/presentation/screens/create_booking_screen.dart';
import 'features/booking/presentation/screens/booking_confirmation_screen.dart';
import 'features/booking/presentation/screens/booking_history_screen.dart';
import 'features/booking/data/datasources/booking_remote_datasource.dart';
import 'features/booking/data/repositories/booking_repository_impl.dart';
import 'features/booking/presentation/screens/fare_offers_screen.dart';
import 'features/provider/presentation/screens/available_bookings_screen.dart';
import 'features/provider/presentation/screens/provider_booking_detail_screen.dart';
import 'features/provider/presentation/screens/provider_tracking_screen.dart';
import 'features/chat/presentation/bloc/chat_bloc.dart';
import 'features/chat/presentation/screens/chat_list_screen.dart';
import 'features/chat/presentation/screens/chat_screen.dart';
import 'features/tracking/presentation/screens/tracking_screen.dart';
import 'features/tracking/presentation/bloc/location_tracking_bloc.dart';
import 'features/feedback/presentation/bloc/feedback_bloc.dart';
import 'features/feedback/presentation/screens/seeker_feedback_screen.dart';
import 'features/feedback/presentation/screens/provider_feedback_screen.dart';
import 'features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'features/feedback/data/repositories/feedback_repository_impl.dart';
import 'features/call/presentation/bloc/call_bloc.dart';
import 'features/call/presentation/screens/incoming_call_screen.dart';
import 'features/call/presentation/screens/outgoing_call_screen.dart';
import 'features/call/presentation/screens/voice_call_screen.dart';
import 'features/call/presentation/screens/video_call_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:latlong2/latlong.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize GraphQL Client
  await GraphQLClientService.instance.initialize();
  
  // Initialize Notification Service
  await NotificationService().initialize();
  
  // Setup notification handling
  _setupNotificationHandling();
  
  runApp(const HaulistryApp());
}

void _setupNotificationHandling() {
  NotificationService().notificationStream.listen((data) {
    final type = data['type'];
    final tapped = data['tapped'] ?? false;

    if (type == NotificationService.notificationTypeCall) {
      // Handle incoming call notification
      final callId = data['callId'] as String;
      final callerId = data['callerId'] as String;
      final callerName = data['callerName'] as String;
      final callerRole = data['callerRole'] as String? ?? 'user';
      final callType = data['callType'] as String;
      
      // Reconstruct agoraConfig including callType
      final agoraConfig = data['agoraConfig'] as Map<String, dynamic>? ?? {
        'appId': data['agoraAppId'] ?? '',
        'channel': data['agoraChannel'] ?? '',
        'token': data['agoraToken'] ?? '',
        'uid': int.tryParse(data['agoraUid']?.toString() ?? '0') ?? 0,
        'callType': callType,
      };

      // Navigate to incoming call screen
      _router.push('/call/incoming', extra: {
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerRole': callerRole,
        'callType': callType,
        'agoraConfig': agoraConfig,
      });
    } else if (tapped) {
      // Handle notification tap navigation for other types
      if (type == NotificationService.notificationTypeChat) {
        // Navigate to chat screen
        // Note: This requires a global navigator key or context
      } else if (type == NotificationService.notificationTypeBooking) {
        // Navigate to booking details
      } else if (type == NotificationService.notificationTypeTracking) {
        // Navigate to tracking screen
      }
    }
  });
}

class HaulistryApp extends StatelessWidget {
  const HaulistryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize repositories
    final graphQLClient = GraphQLClientService.instance;
    
    final serviceDataSource = ServiceRemoteDataSource(graphQLClient: graphQLClient);
    final serviceRepository = ServiceRepositoryImpl(remoteDataSource: serviceDataSource);
    
    final bookingDataSource = BookingRemoteDataSource(graphQLClient: graphQLClient);
    final bookingRepository = BookingRepositoryImpl(remoteDataSource: bookingDataSource);
    
    final providerDataSource = ProviderRemoteDataSource(graphQLClient: graphQLClient);
    final providerRepository = ProviderRepositoryImpl(remoteDataSource: providerDataSource);
    
    final feedbackDataSource = FeedbackRemoteDataSource(baseUrl: AppConstants.apiUrl);
    final feedbackRepository = FeedbackRepositoryImpl(remoteDataSource: feedbackDataSource);
    
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authRepository: AuthRepositoryImpl(),
          )..add(const AuthCheckRequested()),
        ),
        BlocProvider<ServiceBloc>(
          create: (context) => ServiceBloc(repository: serviceRepository)
            ..add(const ServiceLoadRequested()),
        ),
        BlocProvider<BookingBloc>(
          create: (context) => BookingBloc(repository: bookingRepository),
        ),
        BlocProvider<NegotiationBloc>(
          create: (context) => NegotiationBloc(),
        ),
        BlocProvider<ProviderBloc>(
          create: (context) => ProviderBloc(repository: providerRepository),
        ),
        BlocProvider<ChatBloc>(
          create: (context) => ChatBloc(),
        ),
        BlocProvider<FeedbackBloc>(
          create: (context) => FeedbackBloc(repository: feedbackRepository),
        ),
        BlocProvider<CallBloc>(
          create: (context) => CallBloc(),
        ),
        BlocProvider<LocationTrackingBloc>(
          create: (context) => LocationTrackingBloc(),
        ),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// Router Configuration
final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    // Auth Routes
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/phone-auth',
      builder: (context, state) => PhoneAuthScreen(
        extra: state.extra as Map<String, dynamic>?,
      ),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    
    // Service Routes
    GoRoute(
      path: '/service/:serviceType',
      builder: (context, state) {
        final serviceType = state.pathParameters['serviceType'] ?? '';
        return ServiceDetailScreen(serviceType: serviceType);
      },
    ),
    
    // Booking Routes
    GoRoute(
      path: '/booking/create',
      builder: (context, state) {
        final extra = state.extra;
        // Support both ServiceEntity and legacy Map<String, dynamic>
        if (extra is ServiceEntity) {
          return CreateBookingScreen(service: extra);
        } else if (extra is Map<String, dynamic>) {
          final serviceType = extra['serviceType'] as String? ?? '';
          return CreateBookingScreen.fromServiceType(serviceType: serviceType);
        }
        return CreateBookingScreen.fromServiceType(serviceType: '');
      },
    ),
    GoRoute(
      path: '/booking/confirm',
      builder: (context, state) => const BookingConfirmationScreen(),
    ),
    GoRoute(
      path: '/booking/:id/tracking',
      builder: (context, state) {
        final bookingId = state.pathParameters['id'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        
        // Convert pickup location from map to LatLng
        LatLng? pickupLocation;
        if (extra?['pickupLocation'] != null) {
          final pickup = extra!['pickupLocation'];
          if (pickup is LatLng) {
            pickupLocation = pickup;
          } else if (pickup is Map) {
            pickupLocation = LatLng(
              (pickup['latitude'] as num).toDouble(),
              (pickup['longitude'] as num).toDouble(),
            );
          }
        }
        
        // Convert dropoff location from map to LatLng
        LatLng? dropoffLocation;
        if (extra?['dropoffLocation'] != null) {
          final dropoff = extra!['dropoffLocation'];
          if (dropoff is LatLng) {
            dropoffLocation = dropoff;
          } else if (dropoff is Map) {
            dropoffLocation = LatLng(
              (dropoff['latitude'] as num).toDouble(),
              (dropoff['longitude'] as num).toDouble(),
            );
          }
        }
        
        return TrackingScreen(
          bookingId: bookingId,
          providerId: extra?['providerId'] as String? ?? '',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          pickupAddress: extra?['pickupAddress'] as String?,
          dropAddress: extra?['dropAddress'] as String?,
          estimatedPrice: extra?['estimatedPrice'] as double?,
          serviceType: extra?['serviceType'] as String?,
          providerName: extra?['providerName'] as String?,
        );
      },
    ),
    
    // Service Seeker Routes
    GoRoute(
      path: '/seeker/home',
      builder: (context, state) => const SeekerHomeScreen(),
    ),
    GoRoute(
      path: '/seeker/history',
      builder: (context, state) => const BookingHistoryScreen(),
    ),
    GoRoute(
      path: '/booking/:id/offers',
      builder: (context, state) {
        final bookingId = state.pathParameters['id'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        final estimatedPrice = extra?['estimatedPrice'] as double? ?? 0.0;
        return FareOffersScreen(
          bookingId: bookingId,
          estimatedPrice: estimatedPrice,
        );
      },
    ),
    
    // Service Provider Routes
    GoRoute(
      path: '/provider/documents',
      builder: (context, state) {
        final signupData = state.extra as Map<String, dynamic>?;
        return ProviderDocumentsScreen(signupData: signupData);
      },
    ),
    GoRoute(
      path: '/provider/home',
      builder: (context, state) => const ProviderHomeScreen(),
    ),
    GoRoute(
      path: '/provider/vehicles',
      builder: (context, state) => const VehicleManagementScreen(),
    ),
    GoRoute(
      path: '/provider/services',
      builder: (context, state) => const ServiceManagementScreen(),
    ),
    GoRoute(
      path: '/provider/earnings',
      builder: (context, state) => const EarningsDashboardScreen(),
    ),
    GoRoute(
      path: '/provider/available-bookings',
      builder: (context, state) => const AvailableBookingsScreen(),
    ),
    GoRoute(
      path: '/provider/history',
      builder: (context, state) => const BookingHistoryScreen(),
    ),
    GoRoute(
      path: '/provider/booking/:id',
      builder: (context, state) {
        final bookingId = state.pathParameters['id'] ?? '';
        return ProviderBookingDetailScreen(bookingId: bookingId);
      },
    ),
    GoRoute(
      path: '/provider/tracking/:id',
      builder: (context, state) {
        final bookingId = state.pathParameters['id'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        
        // Convert pickup location from map to LatLng
        LatLng? pickupLocation;
        if (extra?['pickupLocation'] != null) {
          final pickup = extra!['pickupLocation'];
          if (pickup is LatLng) {
            pickupLocation = pickup;
          } else if (pickup is Map) {
            pickupLocation = LatLng(
              (pickup['latitude'] as num).toDouble(),
              (pickup['longitude'] as num).toDouble(),
            );
          }
        }
        
        // Convert dropoff location from map to LatLng
        LatLng? dropoffLocation;
        if (extra?['dropoffLocation'] != null) {
          final dropoff = extra!['dropoffLocation'];
          if (dropoff is LatLng) {
            dropoffLocation = dropoff;
          } else if (dropoff is Map) {
            dropoffLocation = LatLng(
              (dropoff['latitude'] as num).toDouble(),
              (dropoff['longitude'] as num).toDouble(),
            );
          }
        }
        
        return ProviderTrackingScreen(
          bookingId: bookingId,
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          pickupAddress: extra?['pickupAddress'] as String?,
          dropAddress: extra?['dropAddress'] as String?,
          estimatedPrice: extra?['estimatedPrice'] as double?,
          serviceType: extra?['serviceType'] as String?,
          bookingStatus: extra?['bookingStatus'] as String?,
        );
      },
    ),
    
    // Profile Routes
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfileScreen(),
    ),
    
    // Chat Routes
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatListScreen(),
    ),
    GoRoute(
      path: '/chat/:conversationId',
      builder: (context, state) {
        final conversationId = state.pathParameters['conversationId'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        final otherUserId = extra?['otherUserId'] as String? ?? '';
        final otherUserName = extra?['otherUserName'] as String? ?? 'User';
        final otherUserImage = extra?['otherUserImage'] as String?;
        final otherUserRole = extra?['otherUserRole'] as String?;
        final bookingId = extra?['bookingId'] as String?;
        return ChatScreen(
          conversationId: conversationId,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserImage: otherUserImage,
          otherUserRole: otherUserRole,
          bookingId: bookingId,
        );
      },
    ),
    
    // Call Routes
    GoRoute(
      path: '/call/incoming',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return BlocProvider.value(
          value: context.read<CallBloc>(),
          child: IncomingCallScreen(
            callId: extra['callId'] as String,
            callerId: extra['callerId'] as String,
            callerName: extra['callerName'] as String,
            callerRole: extra['callerRole'] as String? ?? 'user',
            callerProfileImageUrl: extra['callerProfileImageUrl'] as String?,
            callType: extra['callType'] as String,
            agoraConfig: extra['agoraConfig'] as Map<String, dynamic>,
          ),
        );
      },
    ),
    GoRoute(
      path: '/call/outgoing',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return BlocProvider.value(
          value: context.read<CallBloc>(),
          child: OutgoingCallScreen(
            callId: extra['callId'] as String,
            receiverName: extra['receiverName'] as String,
            receiverRole: extra['receiverRole'] as String? ?? 'user',
            receiverProfileImageUrl: extra['receiverProfileImageUrl'] as String?,
            callType: extra['callType'] as String,
          ),
        );
      },
    ),
    GoRoute(
      path: '/call/voice',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return BlocProvider.value(
          value: context.read<CallBloc>(),
          child: VoiceCallScreen(
            callId: extra['callId'] as String,
            otherUserName: extra['otherUserName'] as String? ?? '',
            otherUserRole: extra['otherUserRole'] as String? ?? 'user',
            otherUserProfileImageUrl: extra['otherUserProfileImageUrl'] as String?,
          ),
        );
      },
    ),
    GoRoute(
      path: '/call/video',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return BlocProvider.value(
          value: context.read<CallBloc>(),
          child: VideoCallScreen(
            callId: extra['callId'] as String,
            otherUserName: extra['otherUserName'] as String? ?? '',
            otherUserRole: extra['otherUserRole'] as String? ?? 'user',
            otherUserProfileImageUrl: extra['otherUserProfileImageUrl'] as String?,
          ),
        );
      },
    ),
    
    // Tracking Route
    GoRoute(
      path: '/tracking/:bookingId',
      builder: (context, state) {
        final bookingId = state.pathParameters['bookingId'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        final providerId = extra?['providerId'] as String? ?? '';
        final pickupLat = extra?['pickupLat'] as double? ?? 0.0;
        final pickupLng = extra?['pickupLng'] as double? ?? 0.0;
        final dropoffLat = extra?['dropoffLat'] as double? ?? 0.0;
        final dropoffLng = extra?['dropoffLng'] as double? ?? 0.0;
        
        return TrackingScreen(
          bookingId: bookingId,
          providerId: providerId,
          pickupLocation: LatLng(pickupLat, pickupLng),
          dropoffLocation: LatLng(dropoffLat, dropoffLng),
          pickupAddress: extra?['pickupAddress'] as String?,
          dropAddress: extra?['dropAddress'] as String?,
          estimatedPrice: extra?['estimatedPrice'] as double?,
          serviceType: extra?['serviceType'] as String?,
          bookingStatus: extra?['bookingStatus'] as String?,
          providerName: extra?['providerName'] as String?,
        );
      },
    ),
    
    // Feedback Routes
    GoRoute(
      path: '/feedback/seeker',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return SeekerFeedbackScreen(
          bookingId: extra['bookingId'] as String,
          providerId: extra['providerId'] as String,
          providerName: extra['providerName'] as String,
        );
      },
    ),
    GoRoute(
      path: '/feedback/provider',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ProviderFeedbackScreen(
          bookingId: extra['bookingId'] as String,
          seekerId: extra['seekerId'] as String,
          seekerName: extra['seekerName'] as String,
        );
      },
    ),
  ],
);
