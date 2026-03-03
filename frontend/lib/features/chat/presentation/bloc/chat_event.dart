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

/// Internal event: conversations stream emitted new data
class _ConversationsUpdated extends ChatEvent {
  final List<Conversation> conversations;

  const _ConversationsUpdated({required this.conversations});

  @override
  List<Object?> get props => [conversations];
}

/// Internal event: conversations stream emitted an error
class _ConversationsError extends ChatEvent {
  final String message;

  const _ConversationsError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Internal event: messages stream emitted new data
class _MessagesUpdated extends ChatEvent {
  final String conversationId;
  final List<ChatMessage> messages;

  const _MessagesUpdated({
    required this.conversationId,
    required this.messages,
  });

  @override
  List<Object?> get props => [conversationId, messages];
}

/// Internal event: messages stream emitted an error
class _MessagesError extends ChatEvent {
  final String message;

  const _MessagesError({required this.message});

  @override
  List<Object?> get props => [message];
}

// Helper classes
class ChatMessage extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.imageUrl,
    required this.timestamp,
    required this.isRead,
  });

  @override
  List<Object?> get props => [
        id,
        senderId,
        senderName,
        message,
        imageUrl,
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
