import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;

  Future<void> initialize() async {
    // Request permission for iOS
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );


    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
      'call_channel',
      'Incoming Calls',
      description: 'This channel is used for incoming call notifications.',
      importance: Importance.max,
      enableLights: true,
      enableVibration: true,
      playSound: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(callChannel);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    // Check if app was opened from a terminated state
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }
  }

  Future<String?> getToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      return token;
    } catch (e) {
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
    } catch (e) {
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
    } catch (e) {
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: _encodePayload(message.data),
      );
    }

    // Also emit to stream for real-time handling
    _notificationStreamController.add(message.data);
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final data = _decodePayload(response.payload!);
      _handleNotificationTap(data);
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    // Emit notification data to stream for navigation
    _notificationStreamController.add({
      ...data,
      'tapped': true,
    });
  }

  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  Map<String, dynamic> _decodePayload(String payload) {
    final map = <String, dynamic>{};
    for (var pair in payload.split('&')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }

  // Show local notification
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data != null ? _encodePayload(data) : null,
    );
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Notification types
  static const String notificationTypeBooking = 'booking';
  static const String notificationTypeChat = 'chat';
  static const String notificationTypeTracking = 'tracking';
  static const String notificationTypePayment = 'payment';
  static const String notificationTypeCall = 'call';

  // Helper methods for specific notification types
  Future<void> showBookingNotification({
    required String bookingId,
    required String title,
    required String body,
  }) async {
    await showLocalNotification(
      id: bookingId.hashCode,
      title: title,
      body: body,
      data: {
        'type': notificationTypeBooking,
        'bookingId': bookingId,
      },
    );
  }

  Future<void> showChatNotification({
    required String conversationId,
    required String senderName,
    required String message,
  }) async {
    await showLocalNotification(
      id: conversationId.hashCode,
      title: senderName,
      body: message,
      data: {
        'type': notificationTypeChat,
        'conversationId': conversationId,
      },
    );
  }

  Future<void> showTrackingNotification({
    required String bookingId,
    required String title,
    required String body,
  }) async {
    await showLocalNotification(
      id: bookingId.hashCode + 1000, // Different ID for tracking
      title: title,
      body: body,
      data: {
        'type': notificationTypeTracking,
        'bookingId': bookingId,
      },
    );
  }

  Future<void> showIncomingCallNotification({
    required String callId,
    required String callerId,
    required String callerName,
    required String callType,
    required Map<String, dynamic> agoraConfig,
  }) async {
    // For Android, show full-screen intent notification
    final androidDetails = AndroidNotificationDetails(
      'call_channel',
      'Incoming Calls',
      channelDescription: 'This channel is used for incoming call notifications.',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.call,
      enableLights: true,
      enableVibration: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('call_ringtone'),
      styleInformation: const BigTextStyleInformation(
        '',
        contentTitle: 'Incoming Call',
      ),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'answer',
          'Answer',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'decline',
          'Decline',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    // For iOS, show high priority notification
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'call_ringtone.caf',
      interruptionLevel: InterruptionLevel.critical,
    );

    await _localNotifications.show(
      callId.hashCode,
      callType == 'video' ? '📹 Video Call' : '📞 Voice Call',
      'Incoming call from $callerName',
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: _encodePayload({
        'type': notificationTypeCall,
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callType': callType,
        'agoraAppId': agoraConfig['appId'] ?? '',
        'agoraChannel': agoraConfig['channel'] ?? '',
        'agoraToken': agoraConfig['token'] ?? '',
        'agoraUid': agoraConfig['uid']?.toString() ?? '0',
      }),
    );

    // Also emit to stream for foreground handling
    _notificationStreamController.add({
      'type': notificationTypeCall,
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callType': callType,
      'agoraConfig': agoraConfig,
      'tapped': false,
    });
  }

  Future<void> cancelCallNotification(String callId) async {
    await _localNotifications.cancel(callId.hashCode);
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
