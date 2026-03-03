import 'package:equatable/equatable.dart';
import 'chat_event.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ConversationsLoaded extends ChatState {
  final List<Conversation> conversations;

  const ConversationsLoaded({required this.conversations});

  @override
  List<Object?> get props => [conversations];
}

class MessagesLoaded extends ChatState {
  final String conversationId;
  final List<ChatMessage> messages;

  const MessagesLoaded({
    required this.conversationId,
    required this.messages,
  });

  @override
  List<Object?> get props => [conversationId, messages];
}

class MessageSending extends ChatState {
  final String conversationId;

  const MessageSending({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

class MessageSent extends ChatState {
  final String conversationId;
  final ChatMessage message;

  const MessageSent({
    required this.conversationId,
    required this.message,
  });

  @override
  List<Object?> get props => [conversationId, message];
}

class ConversationStarted extends ChatState {
  final Conversation conversation;

  const ConversationStarted({required this.conversation});

  @override
  List<Object?> get props => [conversation];
}

class ChatError extends ChatState {
  final String message;

  const ChatError({required this.message});

  @override
  List<Object?> get props => [message];
}
