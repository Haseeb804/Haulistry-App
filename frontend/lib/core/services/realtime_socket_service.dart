import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';

class RealtimeSocketService {
  RealtimeSocketService._internal();

  static final RealtimeSocketService _instance = RealtimeSocketService._internal();
  factory RealtimeSocketService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isConnecting = false;
  bool _isConnected = false;
  bool _closedManually = false;

  Stream<Map<String, dynamic>> get events => _eventsController.stream;
  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    if (_isConnected || _isConnecting) return _isConnected;

    final user = _auth.currentUser;
    if (user == null) {
      _emitLocalError('Realtime connection failed: user not authenticated');
      return false;
    }

    _isConnecting = true;
    _closedManually = false;

    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        _emitLocalError('Realtime connection failed: missing Firebase token');
        _isConnecting = false;
        return false;
      }

      final uri = Uri.parse(AppConstants.realtimeWsUrl).replace(
        queryParameters: {'token': token},
      );

      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (Object error) {
          _emitLocalError('Realtime socket error: $error');
          _markDisconnected();
          _scheduleReconnect();
        },
        onDone: () {
          _markDisconnected();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _isConnected = true;
      _startHeartbeat();
      return true;
    } catch (e) {
      _emitLocalError('Realtime connection failed: $e');
      _markDisconnected();
      _scheduleReconnect();
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    _closedManually = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
  }

  Future<void> send(String type, Map<String, dynamic> data) async {
    if (!_isConnected) {
      final ok = await connect();
      if (!ok) return;
    }

    final payload = {
      'type': type,
      'data': data,
    };

    _channel?.sink.add(jsonEncode(payload));
  }

  void _onMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is Map<String, dynamic>) {
        _eventsController.add(decoded);
      }
    } catch (e) {
      _emitLocalError('Realtime decode error: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_isConnected) {
        _channel?.sink.add(jsonEncode({'type': 'ping', 'data': {}}));
      }
    });
  }

  void _scheduleReconnect() {
    if (_closedManually) return;
    if (_reconnectTimer?.isActive == true) return;

    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      unawaited(connect());
    });
  }

  void _markDisconnected() {
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
  }

  void _emitLocalError(String message) {
    _eventsController.add({
      'type': 'error',
      'ok': false,
      'data': {'message': message},
    });
  }

  void dispose() {
    disconnect();
  }
}
