import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatLoadConversationsRequested extends ChatEvent {
  const ChatLoadConversationsRequested();
}

class ChatLoadMessagesRequested extends ChatEvent {
  final String conversationId;

  const ChatLoadMessagesRequested({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

class ChatSendMessageRequested extends ChatEvent {
  final String conversationId;
  final String message;
  final String? imageUrl;

  const ChatSendMessageRequested({
    required this.conversationId,
    required this.message,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [conversationId, message, imageUrl];
}

class ChatMessageReceived extends ChatEvent {
  final String conversationId;
  final ChatMessage message;

  const ChatMessageReceived({
    required this.conversationId,
    required this.message,
  });

  @override
  List<Object?> get props => [conversationId, message];
}

class ChatMarkAsRead extends ChatEvent {
  final String conversationId;

  const ChatMarkAsRead({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

class ChatStartConversation extends ChatEvent {
  final String otherUserId;
  final String otherUserName;

  const ChatStartConversation({
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  List<Object?> get props => [otherUserId, otherUserName];
}

// Helper classes
class ChatMessage extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final String messageType;
  final String? imageUrl;
  final String? voiceUrl;
  final int? voiceDuration;
  final DateTime timestamp;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.messageType = 'text',
    this.imageUrl,
    this.voiceUrl,
    this.voiceDuration,
    required this.timestamp,
    required this.isRead,
  });

  @override
  List<Object?> get props => [
        id,
        senderId,
        senderName,
        message,
        messageType,
        imageUrl,
        voiceUrl,
        voiceDuration,
        timestamp,
        isRead,
      ];
}

class Conversation extends Equatable {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
    this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        otherUserId,
        otherUserName,
        otherUserImage,
        lastMessage,
        unreadCount,
        updatedAt,
      ];
}
