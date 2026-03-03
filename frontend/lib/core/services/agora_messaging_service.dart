import 'dart:async';
import 'package:agora_rtm/agora_rtm.dart';
import 'api_service.dart';

/// Service for Agora Real-Time Messaging
/// Use this for booking/service-related communication
/// (Firebase Firestore can still be used for general chat)
class AgoraMessagingService {
  static final AgoraMessagingService _instance = AgoraMessagingService._internal();
  factory AgoraMessagingService() => _instance;
  AgoraMessagingService._internal();

  AgoraRtmClient? _client;
  AgoraRtmChannel? _channel;
  String? _currentUserId;
  String? _currentChannelId;
  
  final _messageController = StreamController<AgoraRtmMessage>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  
  Stream<AgoraRtmMessage> get messageStream => _messageController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  
  bool get isConnected => _client != null;

  /// Initialize Agora RTM client
  Future<void> initialize() async {
    try {
      // Get Agora App ID from backend
      final config = await ApiService.instance.get('/messages/agora-config');
      final appId = config['agoraConfig']['appId'];
      
      if (appId == 'your_agora_app_id') {
        return;
      }

      _client = await AgoraRtmClient.createInstance(appId);
      
      // Set up event handlers
      _client?.onMessageReceived = (AgoraRtmMessage message, String peerId) {
        _messageController.add(message);
      };
      
      _client?.onConnectionStateChanged = (int state, int reason) {
        _connectionStateController.add(state == 3); // 3 = Connected
      };
    } catch (e) {
      // silently ignored
    }
  }

  /// Login to Agora RTM with user ID
  Future<bool> login(String userId) async {
    if (_client == null) {
      await initialize();
    }
    
    try {
      await _client?.login(null, userId); // Token can be null for testing
      _currentUserId = userId;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Join a channel (use booking ID as channel name)
  Future<bool> joinChannel(String bookingId) async {
    try {
      // Leave previous channel if exists
      if (_channel != null) {
        await leaveChannel();
      }

      _channel = await _client?.createChannel(bookingId);
      
      // Set up channel message handler
      _channel?.onMessageReceived = (AgoraRtmMessage message, AgoraRtmMember member) {
        _messageController.add(message);
      };

      await _channel?.join();
      _currentChannelId = bookingId;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send a peer-to-peer message
  Future<bool> sendPeerMessage(String peerId, String message) async {
    try {
      final rtmMessage = AgoraRtmMessage.fromText(message);
      await _client?.sendMessageToPeer(peerId, rtmMessage, false);
      
      // Also save to backend
      await _saveToDB(peerId, message);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send a channel message
  Future<bool> sendChannelMessage(String message) async {
    try {
      final rtmMessage = AgoraRtmMessage.fromText(message);
      await _channel?.sendMessage(rtmMessage);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save message to backend database
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
    } catch (e) {
      // silently ignored
    }
  }

  /// Get message history from backend
  Future<List<Map<String, dynamic>>> getMessageHistory(String bookingId) async {
    try {
      final response = await ApiService.instance.get('/messages/booking/$bookingId');
      return List<Map<String, dynamic>>.from(response['messages'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Mark messages as read
  Future<void> markAsRead(String bookingId, String userId) async {
    try {
      await ApiService.instance.post('/messages/mark-read', {
        'receiverId': userId,
        'bookingId': bookingId,
      });
    } catch (e) {
      // silently ignored
    }
  }

  /// Leave current channel
  Future<void> leaveChannel() async {
    try {
      await _channel?.leave();
      _channel = null;
      _currentChannelId = null;
    } catch (e) {
      // silently ignored
    }
  }

  /// Logout from Agora RTM
  Future<void> logout() async {
    try {
      await leaveChannel();
      await _client?.logout();
      _currentUserId = null;
    } catch (e) {
      // silently ignored
    }
  }

  /// Dispose resources
  void dispose() {
    _messageController.close();
    _connectionStateController.close();
    _client?.destroy();
    _client = null;
  }
}
