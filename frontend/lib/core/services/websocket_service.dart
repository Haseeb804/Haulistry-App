import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/app_constants.dart';

/// WebSocket Message Types - Must match backend WSMessageType
class WSMessageType {
  static const String newBookingRequest = 'new_booking_request';
  static const String bookingStatusUpdate = 'booking_status_update';
  static const String bookingCancelled = 'booking_cancelled';

  static const String newFareOffer = 'new_fare_offer';
  static const String fareOfferAccepted = 'fare_offer_accepted';
  static const String fareOfferRejected = 'fare_offer_rejected';
  static const String counterOffer = 'counter_offer';
  static const String offerUpdated = 'offer_updated';
  static const String offerWithdrawn = 'offer_withdrawn';

  static const String locationUpdate = 'location_update';
  static const String requestLocation = 'request_location';

  static const String providerOnline = 'provider_online';
  static const String providerOffline = 'provider_offline';
  static const String providerBusy = 'provider_busy';

  static const String providerArriving = 'provider_arriving';
  static const String providerArrived = 'provider_arrived';
  static const String bookingStarted = 'booking_started';
  static const String bookingCompleted = 'booking_completed';

  static const String ping = 'ping';
  static const String pong = 'pong';
  static const String error = 'error';
  static const String ack = 'ack';
}

/// WebSocket Message wrapper
class WSMessage {
  final String type;
  final Map<String, dynamic> data;
  final String? bookingId;
  final String? senderId;
  final DateTime timestamp;

  WSMessage({
    required this.type,
    required this.data,
    this.bookingId,
    this.senderId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    return WSMessage(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      bookingId: json['bookingId'] as String?,
      senderId: json['senderId'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      'bookingId': bookingId,
      'senderId': senderId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// WebSocket Service for real-time communication
/// Handles connection, reconnection, and message dispatching
class WebSocketService {
  static WebSocketService? _instance;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  bool _isConnected = false;
  String? _userId;
  String _userRole = 'seeker';

  // Reconnection settings
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  // Message stream controllers
  final _messageController = StreamController<WSMessage>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Typed message streams for convenience
  final _bookingRequestController = StreamController<WSMessage>.broadcast();
  final _fareOfferController = StreamController<WSMessage>.broadcast();
  final _locationController = StreamController<WSMessage>.broadcast();
  final _bookingStatusController = StreamController<WSMessage>.broadcast();

  WebSocketService._();

  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }

  /// Stream of all messages
  Stream<WSMessage> get messageStream => _messageController.stream;

  /// Stream of connection status
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Typed streams for specific message types
  Stream<WSMessage> get bookingRequestStream => _bookingRequestController.stream;
  Stream<WSMessage> get fareOfferStream => _fareOfferController.stream;
  Stream<WSMessage> get locationStream => _locationController.stream;
  Stream<WSMessage> get bookingStatusStream => _bookingStatusController.stream;

  bool get isConnected => _isConnected;

  /// Connect to WebSocket server
  Future<void> connect(String userId, {String role = 'seeker'}) async {
    if (_isConnected && _userId == userId) {
      return; // Already connected with same user
    }

    _userId = userId;
    _userRole = role;

    await _establishConnection();
  }

  Future<void> _establishConnection() async {
    try {
      final wsUrl = Uri.parse(
        '${AppConstants.wsEndpoint.replaceFirst('graphql', '')}ws/$_userId?role=$_userRole',
      );


      _channel = WebSocketChannel.connect(wsUrl);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionController.add(true);

      // Start ping timer to keep connection alive
      _startPingTimer();

    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final wsMessage = WSMessage.fromJson(data);

      // Add to main stream
      _messageController.add(wsMessage);

      // Route to typed streams
      _routeMessage(wsMessage);
    } catch (e) {
    }
  }

  void _routeMessage(WSMessage message) {
    switch (message.type) {
      case WSMessageType.newBookingRequest:
        _bookingRequestController.add(message);
        break;

      case WSMessageType.newFareOffer:
      case WSMessageType.fareOfferAccepted:
      case WSMessageType.fareOfferRejected:
      case WSMessageType.counterOffer:
      case WSMessageType.offerUpdated:
      case WSMessageType.offerWithdrawn:
        _fareOfferController.add(message);
        break;

      case WSMessageType.locationUpdate:
        _locationController.add(message);
        break;

      case WSMessageType.bookingStatusUpdate:
      case WSMessageType.bookingCancelled:
      case WSMessageType.providerArriving:
      case WSMessageType.providerArrived:
      case WSMessageType.bookingStarted:
      case WSMessageType.bookingCompleted:
        _bookingStatusController.add(message);
        break;

      case WSMessageType.pong:
        // Handle pong response (connection is alive)
        break;

      case WSMessageType.ack:
        // Acknowledgement received
        break;

      case WSMessageType.error:
        // Error message received
        break;
    }
  }

  void _onError(dynamic error) {
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  void _onDone() {
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      return;
    }

    _reconnectAttempts++;
    final delay = reconnectDelay * _reconnectAttempts;


    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _establishConnection();
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      sendPing();
    });
  }

  /// Send a ping to keep connection alive
  void sendPing() {
    send({
      'type': WSMessageType.ping,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Send a message through WebSocket
  void send(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      // Error sending message
    }
  }

  /// Send location update during active booking
  void sendLocationUpdate({
    String? bookingId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
  }) {
    send({
      'type': WSMessageType.locationUpdate,
      if (bookingId != null) 'bookingId': bookingId,
      'latitude': latitude,
      'longitude': longitude,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
    });
  }

  /// Subscribe provider to a service category
  void subscribeToCategory(String category) {
    send({
      'type': 'subscribe_category',
      'category': category,
    });
  }

  /// Unsubscribe provider from a service category
  void unsubscribeFromCategory(String category) {
    send({
      'type': 'unsubscribe_category',
      'category': category,
    });
  }

  /// Join a booking room for location sharing
  void joinBookingRoom(String bookingId) {
    send({
      'type': 'join_booking',
      'bookingId': bookingId,
    });
  }

  /// Leave a booking room
  void leaveBookingRoom(String bookingId) {
    send({
      'type': 'leave_booking',
      'bookingId': bookingId,
    });
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _userId = null;
    _connectionController.add(false);
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
    _bookingRequestController.close();
    _fareOfferController.close();
    _locationController.close();
    _bookingStatusController.close();
    _instance = null;
  }
}
