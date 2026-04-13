import 'dart:async';
import 'package:agora_rtm/agora_rtm.dart';
import 'api_service.dart';

/// Service for Agora Real-Time Messaging (RTM SDK v2)
/// Use this for booking/service-related communication.
class AgoraMessagingService {
  static final AgoraMessagingService _instance = AgoraMessagingService._internal();
  factory AgoraMessagingService() => _instance;
  AgoraMessagingService._internal();

  RtmClient? _client;
  String? _currentUserId;
  String? _currentChannelId;
  bool _isConnected = false;

  final _messageController = StreamController<MessageEvent>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<MessageEvent> get messageStream => _messageController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _isConnected && _client != null;

  Future<String?> _getAgoraAppId() async {
    try {
      final config = await ApiService.instance.get('/messages/agora-config');
      final appId = config['agoraConfig']?['appId'] as String?;
      if (appId == null || appId.isEmpty || appId == 'your_agora_app_id') {
        return null;
      }
      return appId;
    } catch (_) {
      return null;
    }
  }

  void _attachClientListeners() {
    _client?.addListener(
      linkState: (event) {
        final connected = event.currentState == RtmLinkState.connected;
        _isConnected = connected;
        _connectionStateController.add(connected);
      },
      message: (event) {
        _messageController.add(event);
      },
    );
  }

  /// Login to Agora RTM with user ID
  Future<bool> login(String userId) async {
    try {
      if (_client == null || _currentUserId != userId) {
        final appId = await _getAgoraAppId();
        if (appId == null) {
          return false;
        }

        final (createStatus, client) = await RTM(appId, userId);
        if (createStatus.error) {
          return false;
        }

        _client = client;
        _currentUserId = userId;
        _attachClientListeners();
      }

      final (loginStatus, _) = await _client!.login('');
      _isConnected = !loginStatus.error;
      _connectionStateController.add(_isConnected);
      return _isConnected;
    } catch (_) {
      _isConnected = false;
      _connectionStateController.add(false);
      return false;
    }
  }

  /// Join a message channel (use booking ID as channel name)
  Future<bool> joinChannel(String bookingId) async {
    if (_client == null) return false;

    try {
      if (_currentChannelId != null && _currentChannelId != bookingId) {
        await leaveChannel();
      }

      final (status, _) = await _client!.subscribe(
        bookingId,
        withMessage: true,
        withPresence: true,
      );

      final ok = !status.error;
      if (ok) {
        _currentChannelId = bookingId;
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Send a peer-to-peer message
  Future<bool> sendPeerMessage(String peerId, String message) async {
    if (_client == null) return false;

    try {
      final (status, _) = await _client!.publish(
        peerId,
        message,
        channelType: RtmChannelType.user,
      );

      if (status.error) return false;

      await _saveToDB(peerId, message);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Send a channel message
  Future<bool> sendChannelMessage(String message) async {
    if (_client == null || _currentChannelId == null) return false;

    try {
      final (status, _) = await _client!.publish(_currentChannelId!, message);
      return !status.error;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveToDB(String receiverId, String messageText) async {
    try {
      if (_currentUserId == null || _currentChannelId == null) return;

      await ApiService.instance.post('/messages/send', {
        'senderId': _currentUserId,
        'receiverId': receiverId,
        'bookingId': _currentChannelId,
        'messageText': messageText,
        'messageType': 'text',
      });
    } catch (_) {
      // Non-blocking persistence fallback.
    }
  }

  Future<List<Map<String, dynamic>>> getMessageHistory(String bookingId) async {
    try {
      final response = await ApiService.instance.get('/messages/booking/$bookingId');
      return List<Map<String, dynamic>>.from(response['messages'] ?? []);
    } catch (_) {
      return [];
    }
  }

  Future<void> markAsRead(String bookingId, String userId) async {
    try {
      await ApiService.instance.post('/messages/mark-read', {
        'receiverId': userId,
        'bookingId': bookingId,
      });
    } catch (_) {
      // Non-blocking read acknowledgment.
    }
  }

  /// Leave current channel
  Future<void> leaveChannel() async {
    try {
      if (_client != null && _currentChannelId != null) {
        await _client!.unsubscribe(_currentChannelId!);
      }
    } catch (_) {
      // Best-effort channel leave.
    } finally {
      _currentChannelId = null;
    }
  }

  /// Logout from Agora RTM
  Future<void> logout() async {
    try {
      await leaveChannel();
      await _client?.logout();
      _isConnected = false;
      _connectionStateController.add(false);
      _currentUserId = null;
    } catch (_) {
      // Best-effort logout.
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _client?.release();
    } catch (_) {
      // Best-effort client release.
    }

    _client = null;
    _isConnected = false;
    _currentUserId = null;
    _currentChannelId = null;

    await _messageController.close();
    await _connectionStateController.close();
  }
}
