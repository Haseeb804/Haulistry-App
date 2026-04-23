import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';

class RealtimeSocketService {
  RealtimeSocketService._internal();

  static final RealtimeSocketService _instance = RealtimeSocketService._internal();
  factory RealtimeSocketService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();

  io.Socket? _socket;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isConnecting = false;
  bool _isConnected = false;
  bool _closedManually = false;
  final Random _random = Random();

  final List<_PendingEmit> _pending = [];

  // Completer that resolves once the socket transitions to connected.
  // Avoids the 150ms busy-poll loop that the previous implementation used.
  Completer<bool>? _connectCompleter;

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

      final baseUri = Uri.parse(AppConstants.realtimeWsUrl);
      final socketUri = baseUri.replace(path: '', queryParameters: null);

      _socket?.dispose();
      _socket = io.io(
        socketUri.toString(),
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .enableReconnection()
            .setReconnectionAttempts(999999)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(30000)
            .setRandomizationFactor(0.5)
            .build(),
      );

      _registerListeners();
      _socket!.connect();

      await _ensureConnectivityListener();
      return await _waitUntilConnected();
    } catch (e) {
      _emitLocalError('Realtime connection failed: $e');
      _markDisconnected();
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    _closedManually = true;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
  }

  Future<void> send(String type, Map<String, dynamic> data) async {
    await sendWithAck(type, data, retries: 0);
  }

  Future<Map<String, dynamic>?> sendWithAck(
    String type,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 8),
    int retries = 2,
  }) async {
    if (!_isConnected) {
      final ok = await connect();
      if (!ok || !_isConnected) {
        _pending.add(_PendingEmit(type: type, data: data));
        return null;
      }
    }

    int attempt = 0;
    Object? lastError;

    while (attempt <= retries) {
      try {
        final completer = Completer<Map<String, dynamic>?>();

        _socket?.emitWithAck(type, data, ack: (response) {
          if (response is Map) {
            final casted = response.map((key, value) => MapEntry(key.toString(), value));
            completer.complete(casted);
            return;
          }
          completer.complete(null);
        });

        final ack = await completer.future.timeout(timeout);
        return ack;
      } catch (e) {
        lastError = e;
        attempt += 1;
        if (attempt > retries) break;

        final backoffMs = min(30000, 1000 * (1 << attempt));
        final jitter = _random.nextInt(300);
        await Future<void>.delayed(Duration(milliseconds: backoffMs + jitter));
      }
    }

    _emitLocalError('Realtime send failed for $type: $lastError');
    _pending.add(_PendingEmit(type: type, data: data));
    return null;
  }

  void _registerListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      _isConnected = true;
      _isConnecting = false;
      // Resolve any pending connect() callers without polling.
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete(true);
      }
      unawaited(_flushPending());
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      _isConnecting = false;
      if (!_closedManually) {
        _emitLocalError('Realtime disconnected: $reason');
      }
    });

    _socket!.onConnectError((error) async {
      _isConnected = false;
      _emitLocalError('Realtime connect error: $error');
      await _refreshSocketAuthToken();
      // Resolve with false so connect() callers don't hang forever.
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete(false);
      }
    });

    _socket!.onError((error) {
      _emitLocalError('Realtime socket error: $error');
    });

    const forwardingEvents = <String>[
      'connected',
      'presence_update',
      'presence_state',
      'typing',
      'chat_message',
      'chat_sent',
      'message_status',
      'call_incoming',
      'call_accept',
      'call_reject',
      'call_end',
      'call_status',
      'webrtc_offer',
      'webrtc_answer',
      'webrtc_ice_candidate',
      'location_update',
      'booking_completed',
      'new_booking_request',
      'pong',
      'error',
    ];

    for (final eventName in forwardingEvents) {
      _socket!.on(eventName, (payload) {
        final mapped = payload is Map
            ? payload.map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{'raw': payload};
        _eventsController.add({
          'type': eventName,
          'data': mapped,
        });
      });
    }
  }

  Future<void> _refreshSocketAuthToken() async {
    final user = _auth.currentUser;
    if (user == null || _socket == null) return;

    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) return;
      _socket!.auth = {'token': token};
    } catch (_) {
      // best effort only
    }
  }

  Future<void> _ensureConnectivityListener() async {
    if (_connectivitySubscription != null) return;

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((result) => result != ConnectivityResult.none);
      if (!hasNetwork) return;

      if (!_isConnected && !_closedManually) {
        _socket?.connect();
      }
    });
  }

  Future<void> _flushPending() async {
    if (!_isConnected || _pending.isEmpty) return;

    final snapshot = List<_PendingEmit>.from(_pending);
    _pending.clear();

    for (final item in snapshot) {
      await sendWithAck(item.type, item.data, retries: 1);
    }
  }

  /// Wait for the socket to become connected.  Uses a [Completer] resolved by
  /// [_registerListeners] — no polling loop.
  Future<bool> _waitUntilConnected({Duration timeout = const Duration(seconds: 8)}) async {
    if (_isConnected) return true;

    _connectCompleter = Completer<bool>();
    try {
      return await _connectCompleter!.future.timeout(timeout, onTimeout: () => false);
    } catch (_) {
      return false;
    } finally {
      _connectCompleter = null;
    }
  }

  void _markDisconnected() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
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

class _PendingEmit {
  final String type;
  final Map<String, dynamic> data;

  const _PendingEmit({
    required this.type,
    required this.data,
  });
}
