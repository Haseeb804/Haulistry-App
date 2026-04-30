import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/realtime_socket_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ApiService _apiService;
  final RealtimeSocketService _socketService;
  final FirebaseAuth _auth;

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  ChatBloc({
    ApiService? apiService,
    RealtimeSocketService? socketService,
    FirebaseAuth? auth,
  })  : _apiService = apiService ?? ApiService.instance,
        _socketService = socketService ?? RealtimeSocketService(),
        _auth = auth ?? FirebaseAuth.instance,
        super(const ChatInitial()) {
    on<ChatLoadConversationsRequested>(_onLoadConversationsRequested);
    on<ChatLoadMessagesRequested>(_onLoadMessagesRequested);
    on<ChatSendMessageRequested>(_onSendMessageRequested);
    on<ChatMessageReceived>(_onMessageReceived);
    on<ChatMarkAsRead>(_onMarkAsRead);
    on<ChatStartConversation>(_onStartConversation);

    unawaited(_initRealtime());
  }

  Future<void> _initRealtime() async {
    await _socketService.connect();
    _socketSubscription = _socketService.events.listen((event) {
      final type = event['type']?.toString() ?? '';
      final data = (event['data'] is Map<String, dynamic>)
          ? event['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      if (type == 'chat_message') {
        final messageMap = (data['message'] is Map<String, dynamic>)
          ? data['message'] as Map<String, dynamic>
          : <String, dynamic>{};
        final message = _toChatMessage(messageMap);

        final bookingId = messageMap['bookingId']?.toString() ?? '';
        final senderId = message.senderId;

        if (bookingId.isNotEmpty && senderId.isNotEmpty) {
          add(ChatMessageReceived(
            conversationId: '$bookingId:$senderId',
            message: message,
          ));
        }
      }
    });
  }

  Future<void> _onLoadConversationsRequested(
    ChatLoadConversationsRequested event,
    Emitter<ChatState> emit,
  ) async {
    try {
      emit(const ChatLoading());

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        emit(const ChatError(message: 'User not authenticated'));
        return;
      }

      final response = await _apiService.get('/api/messages/conversations/${currentUser.uid}');
      final rows = (response['conversations'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      final conversations = rows.map((row) {
        final last = (row['lastMessage'] is Map<String, dynamic>)
            ? row['lastMessage'] as Map<String, dynamic>
            : <String, dynamic>{};

        return Conversation(
          id: row['id']?.toString() ?? '',
          otherUserId: row['otherUserId']?.toString() ?? '',
          otherUserName: row['otherUserName']?.toString() ?? 'User',
          otherUserImage: row['otherUserImage']?.toString(),
          lastMessage: last.isEmpty ? null : _toChatMessage(last),
          unreadCount: (row['unreadCount'] is int)
              ? row['unreadCount'] as int
              : int.tryParse(row['unreadCount']?.toString() ?? '0') ?? 0,
          updatedAt: DateTime.tryParse(row['updatedAt']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();

      emit(ConversationsLoaded(conversations: conversations));
    } catch (e) {
      emit(ChatError(message: 'Failed to load conversations: $e'));
    }
  }

  Future<void> _onLoadMessagesRequested(
    ChatLoadMessagesRequested event,
    Emitter<ChatState> emit,
  ) async {
    try {
      emit(const ChatLoading());

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        emit(const ChatError(message: 'User not authenticated'));
        return;
      }

      final parts = event.conversationId.split(':');
      if (parts.length < 2) {
        emit(const MessagesLoaded(conversationId: '', messages: []));
        return;
      }

      final bookingId = parts[0];
      final otherUserId = parts[1];

      final response = await _apiService.get(
        ApiEndpoints.conversationMessages(currentUser.uid, otherUserId, bookingId),
      );

      final rows = (response['messages'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      final messages = rows.map(_toChatMessage).toList();

      emit(MessagesLoaded(
        conversationId: event.conversationId,
        messages: messages,
      ));
    } catch (e) {
      emit(ChatError(message: 'Failed to load messages: $e'));
    }
  }

  Future<void> _onSendMessageRequested(
    ChatSendMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    try {
      emit(MessageSending(conversationId: event.conversationId));

      final parts = event.conversationId.split(':');
      if (parts.length < 2) {
        emit(const ChatError(message: 'Invalid conversation id'));
        return;
      }

      final bookingId = parts[0];
      final receiverId = parts[1];
      final clientMessageId = '${DateTime.now().microsecondsSinceEpoch}_${receiverId.hashCode}';

      final ack = await _socketService.sendWithAck('chat_send', {
        'receiverId': receiverId,
        'bookingId': bookingId,
        'messageText': event.imageUrl ?? event.message,
        'messageType': event.imageUrl != null ? 'image' : 'text',
        'clientMessageId': clientMessageId,
      });

      if (ack != null && ack['ok'] == true) {
        final data = (ack['data'] is Map<String, dynamic>)
            ? ack['data'] as Map<String, dynamic>
            : <String, dynamic>{};
        final messageMap = (data['message'] is Map<String, dynamic>)
            ? data['message'] as Map<String, dynamic>
            : <String, dynamic>{};

        if (messageMap.isNotEmpty) {
          emit(MessageSent(
            conversationId: event.conversationId,
            message: _toChatMessage(messageMap),
          ));
        }
      }
    } catch (e) {
      emit(ChatError(message: 'Failed to send message: $e'));
    }
  }

  Future<void> _onMessageReceived(
    ChatMessageReceived event,
    Emitter<ChatState> emit,
  ) async {
    if (state is MessagesLoaded) {
      final current = state as MessagesLoaded;
      if (current.conversationId == event.conversationId) {
        emit(MessagesLoaded(
          conversationId: current.conversationId,
          messages: [event.message, ...current.messages],
        ));
      }
    }
  }

  Future<void> _onMarkAsRead(
    ChatMarkAsRead event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final parts = event.conversationId.split(':');
      if (parts.length < 2) return;

      final bookingId = parts[0];

      await _apiService.post('/api/messages/mark-read', {
        'receiverId': currentUser.uid,
        'bookingId': bookingId,
      });
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> _onStartConversation(
    ChatStartConversation event,
    Emitter<ChatState> emit,
  ) async {
    emit(ConversationStarted(
      conversation: Conversation(
        id: 'new:${event.otherUserId}',
        otherUserId: event.otherUserId,
        otherUserName: event.otherUserName,
        otherUserImage: null,
        lastMessage: null,
        unreadCount: 0,
        updatedAt: DateTime.now(),
      ),
    ));
  }

  ChatMessage _toChatMessage(Map<String, dynamic> row) {
    final messageType = (row['messageType']?.toString() ?? 'text').toLowerCase();
    final messageText = row['messageText']?.toString() ?? row['message']?.toString() ?? '';

    final senderProfileImageUrl = row['senderProfileImageUrl']?.toString();

    return ChatMessage(
      id: row['id']?.toString() ?? '',
      senderId: row['senderId']?.toString() ?? '',
      senderName: row['senderName']?.toString() ?? 'User',
      senderProfileImageUrl: (senderProfileImageUrl?.isNotEmpty == true) ? senderProfileImageUrl : null,
      message: (messageType == 'text' || messageType == 'call') ? messageText : '',
      messageType: messageType,
      imageUrl: messageType == 'image' ? messageText : row['imageUrl']?.toString(),
      voiceUrl: messageType == 'voice' ? messageText : row['voiceUrl']?.toString(),
      voiceDuration: row['voiceDuration'] is int
          ? row['voiceDuration'] as int
          : int.tryParse(row['voiceDuration']?.toString() ?? ''),
      timestamp: DateTime.tryParse(
            row['timestamp']?.toString() ?? row['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      isRead: row['isRead'] == true,
    );
  }

  @override
  Future<void> close() async {
    await _socketSubscription?.cancel();
    return super.close();
  }
}
