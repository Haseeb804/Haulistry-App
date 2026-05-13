import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'core/data/graphql_client.dart';
import 'features/auth/data/repository/auth_repository_impl.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
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
import 'features/booking/presentation/screens/request_status_screen.dart';
import 'features/booking/data/datasources/booking_remote_datasource.dart';
import 'features/booking/data/repositories/booking_repository_impl.dart';
import 'features/booking/presentation/screens/request_accepted_screen.dart';
import 'features/provider/presentation/screens/provider_booking_detail_screen.dart';
import 'features/provider/presentation/screens/provider_request_review_screen.dart';
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
import 'features/call/presentation/bloc/call_event.dart';
import 'features/call/presentation/bloc/call_state.dart';
import 'features/call/presentation/screens/incoming_call_screen.dart';
import 'features/call/presentation/screens/outgoing_call_screen.dart';
import 'features/call/presentation/screens/voice_call_screen.dart';
import 'features/call/presentation/screens/video_call_screen.dart';
import 'features/call/presentation/screens/call_history_screen.dart';
import 'features/call/presentation/widgets/floating_call_bar.dart';
import 'features/notifications/presentation/bloc/notification_bloc.dart';
import 'features/notifications/presentation/bloc/notification_event.dart';
import 'features/notifications/presentation/screens/notifications_screen.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/services/realtime_socket_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:latlong2/latlong.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLifecycleService().initialize(onResumed: _handleAppResume);

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

  // Pre-warm the realtime socket as soon as the user signs in so incoming
  // calls and chat events arrive instantly instead of after lazy init.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      unawaited(RealtimeSocketService().connect());
    } else {
      unawaited(RealtimeSocketService().disconnect());
    }
  });

  runApp(const HaulistryApp());
}

void _setupNotificationHandling() {
  NotificationService().notificationStream.listen((data) {
    final type = data['type']?.toString();
    final tapped = data['tapped'] ?? false;

    if (type == 'booking_accepted' ||
      type == 'booking_status_update' ||
      type == 'tracking') {
      final bookingId = data['bookingId']?.toString();
      final bookingStatus = (data['status'] ?? data['bookingStatus'] ?? '').toString().toLowerCase();

      if (bookingId != null && bookingId.isNotEmpty &&
          (type == 'booking_accepted' ||
              bookingStatus == AppConstants.statusActive ||
              bookingStatus == AppConstants.statusAccepted)) {
        // Never let a booking notification navigate over an active call screen.
        final ctx = _rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          final cs = ctx.read<CallBloc>().state;
          if (cs is CallInitiated || cs is CallRinging ||
              cs is CallConnecting || cs is CallConnected) {
            return;
          }
        }
        unawaited(_navigateToTrackingFromBooking(bookingId));
      }
    }

    if (type == NotificationService.notificationTypeCall) {
      // Handle incoming call notification
      final callId = data['callId']?.toString() ?? '';
      final callerId = data['callerId']?.toString() ?? '';
      final callerName = data['callerName']?.toString() ?? 'User';
      final callerRole = data['callerRole']?.toString() ?? AppConstants.roleUser;
      final callerProfileImageUrl = data['callerProfileImageUrl']?.toString();
      final callType = data['callType']?.toString() ?? AppConstants.callTypeVoice;

      final nestedSignalData =
        (data['signalData'] is Map<String, dynamic>)
          ? data['signalData'] as Map<String, dynamic>
          : <String, dynamic>{};

      final signalData = {
        'callId': nestedSignalData['callId']?.toString() ?? callId,
        'bookingId': nestedSignalData['bookingId']?.toString() ?? data['bookingId']?.toString() ?? '',
        'callType': nestedSignalData['callType']?.toString() ?? callType,
        'signalingChannel': nestedSignalData['signalingChannel']?.toString() ?? data['signalingChannel']?.toString() ?? '',
        'sessionId': nestedSignalData['sessionId']?.toString() ?? data['sessionId']?.toString() ?? '',
        'callerId': nestedSignalData['callerId']?.toString() ?? callerId,
        'receiverId': nestedSignalData['receiverId']?.toString() ?? data['receiverId']?.toString() ?? '',
      };

      _navigateToIncomingCall(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerRole: callerRole,
        callerProfileImageUrl: callerProfileImageUrl,
        callType: callType,
        signalData: signalData,
      );
    } else if (type == 'call_end') {
      // FCM fallback when call ends while receiver is in background.
      final callId = data['callId']?.toString() ?? '';
      if (callId.isEmpty) return;

      _shownIncomingCallIds.remove(callId);

      final ctx = _rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ctx.read<CallBloc>().add(RemoteCallStatusUpdated(
          callId: callId,
          status: AppConstants.callStatusEnded,
          duration: int.tryParse(data['duration']?.toString() ?? '0') ?? 0,
        ));
      }
    } else if (type == 'call_status') {
      final callId = data['callId']?.toString() ?? '';
      final status = data['status']?.toString().toLowerCase() ?? '';
      if (callId.isEmpty) return;

      // Only auto-route on call_status for CALLER when receiver accepts
      // Receiver should NOT auto-route because they just accepted and are navigating
      // This prevents double-navigation and auto-accept behavior
      // Note: The BLoC listener in call screens will handle the actual state transitions
      if (status == 'answered') {
        // Don't auto-route here; let the app handle it normally
        // The incoming call screen's BlocListener will take care of navigation
        // when the BLoC reaches CallConnecting state
        return;
      }
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

Future<void> _handleAppResume() async {
  try {
    final context = _rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    // ── Critical guard ─────────────────────────────────────────────────────────
    // _router.go() replaces the ENTIRE navigation stack. If a call is active,
    // navigating here would silently close the call screens while the WebRTC
    // peer connection keeps running invisibly — creating a "ghost" background
    // call. This is the root cause of "outgoing screen disappears after 5-6s".
    final callState = context.read<CallBloc>().state;
    if (callState is CallInitiated ||
        callState is CallRinging ||
        callState is CallConnecting ||
        callState is CallConnected) {
      return;
    }

    final user = authState.user;
    final bookingRepository = BookingRepositoryImpl(
      remoteDataSource: BookingRemoteDataSource(
        graphQLClient: GraphQLClientService.instance,
      ),
    );
    final feedbackRepository = FeedbackRepositoryImpl(
      remoteDataSource: FeedbackRemoteDataSource(baseUrl: AppConstants.apiUrl),
    );

    final bookings = await bookingRepository.getBookingHistory(user.id);
    if (!context.mounted) return;

    final activeBookings = bookings
        .where((b) => AppConstants.activeServiceStatuses.contains(b.status.toLowerCase()))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (activeBookings.isNotEmpty) {
      // Re-check call state: the user may have initiated a call while the
      // booking fetch was in-flight. A second guard here prevents _router.go()
      // from replacing the navigation stack over an in-progress call screen.
      if (!context.mounted) return;
      final callStateNow = context.read<CallBloc>().state;
      if (callStateNow is CallInitiated ||
          callStateNow is CallRinging ||
          callStateNow is CallConnecting ||
          callStateNow is CallConnected) {
        return;
      }

      final booking = activeBookings.first;
      if (user.role == AppConstants.roleProvider) {
        _router.go(
          AppRoutes.providerTracking(booking.id),
          extra: {
            'pickupLocation': {
              'latitude': booking.pickupLatitude,
              'longitude': booking.pickupLongitude,
            },
            'dropoffLocation': {
              'latitude': booking.dropLatitude,
              'longitude': booking.dropLongitude,
            },
            'pickupAddress': booking.pickupAddress,
            'dropAddress': booking.dropAddress,
            'estimatedPrice': booking.estimatedPrice,
            'serviceType': booking.serviceType,
            'bookingStatus': booking.status,
            'providerName': booking.providerName,
          },
        );
      } else {
        _router.go(
          AppConstants.seekerTrackingPath(booking.id),
          extra: {
            'providerId': booking.providerId ?? '',
            'pickupLocation': {
              'latitude': booking.pickupLatitude,
              'longitude': booking.pickupLongitude,
            },
            'dropoffLocation': {
              'latitude': booking.dropLatitude,
              'longitude': booking.dropLongitude,
            },
            'pickupAddress': booking.pickupAddress,
            'dropAddress': booking.dropAddress,
            'estimatedPrice': booking.estimatedPrice,
            'serviceType': booking.serviceType,
            'providerName': booking.providerName,
            'bookingStatus': booking.status,
          },
        );
      }
      return;
    }

    final completedBookings = bookings
        .where((b) => b.status.toLowerCase() == AppConstants.statusCompleted)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    for (final booking in completedBookings) {
      if (user.role == AppConstants.roleProvider) {
        if (booking.seekerId.isEmpty) continue;
        final exists = await feedbackRepository.checkFeedbackExists(booking.id, AppConstants.roleProvider);
        if (!context.mounted || exists) return;

        // Same call-state guard before any _router.go() call.
        final cs2 = context.read<CallBloc>().state;
        if (cs2 is CallInitiated || cs2 is CallRinging ||
            cs2 is CallConnecting || cs2 is CallConnected) return;

        _router.go(AppRoutes.feedbackProvider, extra: {
          'bookingId': booking.id,
          'seekerId': booking.seekerId,
          'seekerName': booking.seekerName ?? 'Customer',
        });
        return;
      } else {
        if (booking.providerId == null || booking.providerId!.isEmpty) continue;
        final exists = await feedbackRepository.checkFeedbackExists(booking.id, AppConstants.roleSeeker);
        if (!context.mounted || exists) return;

        final cs3 = context.read<CallBloc>().state;
        if (cs3 is CallInitiated || cs3 is CallRinging ||
            cs3 is CallConnecting || cs3 is CallConnected) return;

        _router.go(AppRoutes.feedbackSeeker, extra: {
          'bookingId': booking.id,
          'providerId': booking.providerId ?? '',
          'providerName': booking.providerName ?? 'Provider',
        });
        return;
      }
    }
  } catch (_) {
    // Non-blocking fallback: if the resume check fails, normal dashboard loading continues.
  }
}

final Set<String> _shownIncomingCallIds = <String>{};

void _navigateToIncomingCall({
  required String callId,
  required String callerId,
  required String callerName,
  required String callerRole,
  required String? callerProfileImageUrl,
  required String callType,
  required Map<String, dynamic> signalData,
}) {
  // Ignore malformed payloads and duplicate navigation for the same call.
  if (callId.isEmpty || callerId.isEmpty || _shownIncomingCallIds.contains(callId)) {
    return;
  }

  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId != null && callerId == currentUserId) {
    return;
  }

  _shownIncomingCallIds.add(callId);

  _router.push(AppRoutes.callIncoming, extra: {
    'callId': callId,
    'callerId': callerId,
    'callerName': callerName,
    'callerRole': callerRole,
    'callerProfileImageUrl': callerProfileImageUrl,
    'callType': callType,
    'signalData': signalData,
  });
}

Future<void> _navigateToTrackingFromBooking(String bookingId) async {
  try {
    final response = await ApiService.instance.getBooking(bookingId);
    if (response['success'] != true || response['booking'] == null) return;

    final booking = response['booking'] as Map<String, dynamic>;
    final providerId = (booking['providerId'] ?? booking['provider_id'])?.toString() ?? '';
    if (providerId.isEmpty) return;

    final pickupLatitude = (booking['pickupLatitude'] ?? booking['pickup_latitude'] as num?)?.toDouble();
    final pickupLongitude = (booking['pickupLongitude'] ?? booking['pickup_longitude'] as num?)?.toDouble();
    final dropLatitude = (booking['dropLatitude'] ?? booking['drop_latitude'] as num?)?.toDouble();
    final dropLongitude = (booking['dropLongitude'] ?? booking['drop_longitude'] as num?)?.toDouble();

    _router.go(
      AppRoutes.seekerTracking(bookingId),
      extra: {
        'providerId': providerId,
        'providerName': booking['providerName']?.toString(),
        'pickupLocation': (pickupLatitude != null && pickupLongitude != null)
            ? LatLng(pickupLatitude, pickupLongitude)
            : null,
        'dropoffLocation': (dropLatitude != null && dropLongitude != null)
            ? LatLng(dropLatitude, dropLongitude)
            : null,
        'pickupAddress': booking['pickupAddress']?.toString(),
        'dropAddress': booking['dropAddress']?.toString(),
        'estimatedPrice': (booking['estimatedPrice'] ?? booking['estimated_price']) is num
            ? ((booking['estimatedPrice'] ?? booking['estimated_price']) as num).toDouble()
            : null,
        'serviceType': booking['serviceType']?.toString(),
        'bookingStatus': booking['status']?.toString(),
      },
    );
  } catch (_) {
    // Non-blocking fallback: if the fetch fails, the polling screens will still catch up.
  }
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
        BlocProvider<NotificationBloc>(
          create: (context) => NotificationBloc(),
        ),
      ],
      child: MaterialApp.router(
        builder: (context, child) {
          return MultiBlocListener(
            listeners: [
              // Show incoming call screen when a call rings for this user.
              BlocListener<CallBloc, CallState>(
                listenWhen: (previous, current) => current is CallRinging,
                listener: (context, state) {
                  if (state is! CallRinging) return;
                  _navigateToIncomingCall(
                    callId: state.callId,
                    callerId: state.callerId,
                    callerName: state.callerName,
                    callerRole: state.callerRole,
                    callerProfileImageUrl: state.callerProfileImageUrl,
                    callType: state.callType,
                    signalData: state.signalData,
                  );
                },
              ),
              // Show outgoing call screen when the current user places a call.
              BlocListener<CallBloc, CallState>(
                listenWhen: (previous, current) =>
                    current is CallInitiated && previous is! CallInitiated,
                listener: (context, state) {
                  if (state is! CallInitiated) return;
                  _router.push(AppRoutes.callOutgoing, extra: {
                    'callId': state.callId,
                    'receiverId': state.receiverId,
                    'receiverName': state.receiverName,
                    'receiverRole': state.receiverRole,
                    'receiverProfileImageUrl': state.receiverProfileImageUrl,
                    'callType': state.callType,
                  });
                },
              ),
              // Show a snackbar when a call fails to START (pre-connect error).
              // Scoped to CallLoading → CallError only: the call screens
              // (voice/video/outgoing) already show their own snackbars for
              // mid-call errors, so this avoids duplicate feedback.
              BlocListener<CallBloc, CallState>(
                listenWhen: (previous, current) =>
                    current is CallError && previous is CallLoading,
                listener: (context, state) {
                  if (state is! CallError) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              // Clean up the seen-calls deduplication set when a call ends so
              // the same callId cannot prevent a future incoming screen from showing.
              BlocListener<CallBloc, CallState>(
                listenWhen: (previous, current) =>
                    current is CallEnded && previous is! CallEnded,
                listener: (context, state) {
                  if (state is CallEnded && state.callId.isNotEmpty) {
                    _shownIncomingCallIds.remove(state.callId);
                  }
                },
              ),
              // Load notifications and subscribe to real-time events on login.
              BlocListener<AuthBloc, AuthState>(
                listenWhen: (previous, current) =>
                    previous is! AuthAuthenticated && current is AuthAuthenticated,
                listener: (context, state) {
                  if (state is AuthAuthenticated) {
                    final notifBloc = context.read<NotificationBloc>();
                    notifBloc.subscribeToSocket(state.user.id);
                    notifBloc.add(NotificationsLoadRequested(state.user.id));
                  }
                  unawaited(_handleAppResume());
                },
              ),
            ],
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const Align(
                  alignment: Alignment.topCenter,
                  child: FloatingCallBar(),
                ),
              ],
            ),
          );
        },
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
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.login,
  routes: [
    // Auth Routes
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: AppRoutes.phoneAuth,
      builder: (context, state) => PhoneAuthScreen(
        extra: state.extra as Map<String, dynamic>?,
      ),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    
    // Service Routes
    GoRoute(
      path: AppRoutes.serviceByTypePattern,
      builder: (context, state) {
        final serviceType = state.pathParameters['serviceType'] ?? '';
        final extra = state.extra;
        // When navigated from seeker home, extra carries the full ServiceEntity
        // (provider name, real pricing, extraFields, vehicle image, location, etc.)
        if (extra is ServiceEntity) {
          return ServiceDetailScreen(serviceType: serviceType, service: extra);
        }
        return ServiceDetailScreen(serviceType: serviceType);
      },
    ),
    
    // Booking Routes
    GoRoute(
      path: AppRoutes.bookingCreate,
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
      path: AppRoutes.bookingConfirm,
      builder: (context, state) => const BookingConfirmationScreen(),
    ),
    GoRoute(
      path: AppRoutes.bookingStatusPattern,
      builder: (context, state) {
        final bookingId = state.pathParameters['id'] ?? '';
        return RequestStatusScreen(bookingId: bookingId);
      },
    ),
    GoRoute(
      path: AppConstants.routeSeekerTrackingPattern,
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
          bookingStatus: extra?['bookingStatus'] as String?,
          providerName: extra?['providerName'] as String?,
        );
      },
    ),
    GoRoute(
      path: AppConstants.routeSeekerAcceptedPattern,
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

        return RequestAcceptedScreen(
          bookingId: bookingId,
          providerId: extra?['providerId'] as String? ?? '',
          providerName: extra?['providerName'] as String?,
          serviceType: extra?['serviceType'] as String?,
          bookingStatus: extra?['bookingStatus'] as String?,
          pickupAddress: extra?['pickupAddress'] as String?,
          dropAddress: extra?['dropAddress'] as String?,
          estimatedPrice: extra?['estimatedPrice'] as double?,
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
        );
      },
    ),
    
    // Service Seeker Routes
    GoRoute(
      path: AppRoutes.seekerHome,
      builder: (context, state) => const SeekerHomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.seekerHistory,
      builder: (context, state) => const BookingHistoryScreen(),
    ),
    
    // Service Provider Routes
    GoRoute(
      path: AppRoutes.providerDocuments,
      builder: (context, state) {
        final signupData = state.extra as Map<String, dynamic>?;
        return ProviderDocumentsScreen(signupData: signupData);
      },
    ),
    GoRoute(
      path: AppRoutes.providerHome,
      builder: (context, state) => const ProviderHomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.providerVehicles,
      builder: (context, state) => const VehicleManagementScreen(),
    ),
    GoRoute(
      path: AppRoutes.providerServices,
      builder: (context, state) => const ServiceManagementScreen(),
    ),
    GoRoute(
      path: AppRoutes.providerEarnings,
      builder: (context, state) => const EarningsDashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.providerHistory,
      builder: (context, state) => const BookingHistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.providerBookingPattern,
      builder: (context, state) {
        final bookingId = state.pathParameters['id'] ?? '';
        return ProviderBookingDetailScreen(bookingId: bookingId);
      },
    ),
    GoRoute(
      path: AppRoutes.providerRequestPattern,
      builder: (context, state) {
        final bookingId = state.pathParameters['id'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        final bookingData = extra?['booking'] as Map<String, dynamic>?;
        return ProviderRequestReviewScreen(
          bookingId: bookingId,
          initialBookingData: bookingData,
        );
      },
    ),
    GoRoute(
      path: AppConstants.routeProviderTrackingPattern,
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
      path: AppRoutes.profile,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.profileEdit,
      builder: (context, state) => const EditProfileScreen(),
    ),
    
    // Chat Routes
    GoRoute(
      path: AppRoutes.chatList,
      builder: (context, state) => const ChatListScreen(),
    ),
    GoRoute(
      path: AppRoutes.chatPattern,
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
      path: AppRoutes.callIncoming,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return BlocProvider.value(
          value: context.read<CallBloc>(),
          child: IncomingCallScreen(
            callId: extra['callId'] as String,
            callerId: extra['callerId'] as String,
            callerName: extra['callerName'] as String,
            callerRole: extra['callerRole'] as String? ?? AppConstants.roleUser,
            callerProfileImageUrl: extra['callerProfileImageUrl'] as String?,
            callType: extra['callType'] as String,
            signalData: extra['signalData'] as Map<String, dynamic>,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.callOutgoing,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return BlocProvider.value(
          value: context.read<CallBloc>(),
          child: OutgoingCallScreen(
            callId: extra['callId'] as String,
            receiverId: extra['receiverId'] as String? ?? '',
            receiverName: extra['receiverName'] as String,
            receiverRole: extra['receiverRole'] as String? ?? AppConstants.roleUser,
            receiverProfileImageUrl: extra['receiverProfileImageUrl'] as String?,
            callType: extra['callType'] as String,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.callVoice,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return BlocProvider.value(
          value: context.read<CallBloc>(),
          child: VoiceCallScreen(
            callId: extra['callId'] as String,
            otherUserId: extra['otherUserId'] as String? ?? '',
            otherUserName: extra['otherUserName'] as String? ?? '',
            otherUserRole: extra['otherUserRole'] as String? ?? AppConstants.roleUser,
            otherUserProfileImageUrl: extra['otherUserProfileImageUrl'] as String?,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.callVideo,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return BlocProvider.value(
          value: context.read<CallBloc>(),
          child: VideoCallScreen(
            callId: extra['callId'] as String,
            otherUserId: extra['otherUserId'] as String? ?? '',
            otherUserName: extra['otherUserName'] as String? ?? '',
            otherUserRole: extra['otherUserRole'] as String? ?? AppConstants.roleUser,
            otherUserProfileImageUrl: extra['otherUserProfileImageUrl'] as String?,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.callHistory,
      builder: (context, state) => BlocProvider.value(
        value: context.read<CallBloc>(),
        child: const CallHistoryScreen(),
      ),
    ),

    // Tracking Route
    GoRoute(
      path: AppConstants.routeLegacyTrackingPattern,
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
    
    // Notifications Route
    GoRoute(
      path: AppRoutes.notifications,
      builder: (context, state) => BlocProvider.value(
        value: context.read<NotificationBloc>(),
        child: const NotificationsScreen(),
      ),
    ),

    // Feedback Routes
    GoRoute(
      path: AppRoutes.feedbackSeeker,
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
      path: AppRoutes.feedbackProvider,
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
