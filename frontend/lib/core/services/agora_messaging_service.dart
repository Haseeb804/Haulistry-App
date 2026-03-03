import 'dart:async';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:flutter/foundation.dart';
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
        debugPrint('⚠️ Agora App ID not configured in backend');
        return;
      }

      _client = await AgoraRtmClient.createInstance(appId);
      
      // Set up event handlers
      _client?.onMessageReceived = (AgoraRtmMessage message, String peerId) {
        debugPrint('📩 Message from $peerId: ${message.text}');
        _messageController.add(message);
      };
      
      _client?.onConnectionStateChanged = (int state, int reason) {
        debugPrint('🔗 RTM Connection state: $state, reason: $reason');
        _connectionStateController.add(state == 3); // 3 = Connected
      };

      debugPrint('✅ Agora RTM Client initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Agora RTM: $e');
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
      debugPrint('✅ Logged in to Agora RTM as $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to login to Agora RTM: $e');
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
        debugPrint('📩 Channel message from ${member.userId}: ${message.text}');
        _messageController.add(message);
      };

      await _channel?.join();
      _currentChannelId = bookingId;
      debugPrint('✅ Joined channel: $bookingId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to join channel: $e');
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
      
      debugPrint('✅ Sent message to $peerId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');
      return false;
    }
  }

  /// Send a channel message
  Future<bool> sendChannelMessage(String message) async {
    try {
      final rtmMessage = AgoraRtmMessage.fromText(message);
      await _channel?.sendMessage(rtmMessage);
      debugPrint('✅ Sent channel message');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send channel message: $e');
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
      debugPrint('⚠️ Failed to save message to DB: $e');
    }
  }

  /// Get message history from backend
  Future<List<Map<String, dynamic>>> getMessageHistory(String bookingId) async {
    try {
      final response = await ApiService.instance.get('/messages/booking/$bookingId');
      return List<Map<String, dynamic>>.from(response['messages'] ?? []);
    } catch (e) {
      debugPrint('❌ Failed to load message history: $e');
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
      debugPrint('⚠️ Failed to mark messages as read: $e');
    }
  }

  /// Leave current channel
  Future<void> leaveChannel() async {
    try {
      await _channel?.leave();
      _channel = null;
      _currentChannelId = null;
      debugPrint('✅ Left channel');
    } catch (e) {
      debugPrint('❌ Failed to leave channel: $e');
    }
  }

  /// Logout from Agora RTM
  Future<void> logout() async {
    try {
      await leaveChannel();
      await _client?.logout();
      _currentUserId = null;
      debugPrint('✅ Logged out from Agora RTM');
    } catch (e) {
      debugPrint('❌ Failed to logout: $e');
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
