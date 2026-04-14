import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _conversationsSubscription;
  StreamSubscription? _messagesSubscription;

  ChatBloc() : super(const ChatInitial()) {
    on<ChatLoadConversationsRequested>(_onLoadConversationsRequested);
    on<ChatLoadMessagesRequested>(_onLoadMessagesRequested);
    on<ChatSendMessageRequested>(_onSendMessageRequested);
    on<ChatMessageReceived>(_onMessageReceived);
    on<ChatMarkAsRead>(_onMarkAsRead);
    on<ChatStartConversation>(_onStartConversation);
    on<_ConversationsUpdated>(_onConversationsUpdated);
    on<_ConversationsError>(_onConversationsError);
    on<_MessagesUpdated>(_onMessagesUpdated);
    on<_MessagesError>(_onMessagesError);
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

      // Cancel previous subscription
      await _conversationsSubscription?.cancel();

      // Listen to conversations in real-time — dispatch events via add()
      // so that emit is used from within proper event handlers.
      _conversationsSubscription = _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUser.uid)
          .snapshots()
          .listen((snapshot) async {
        try {
          final conversations = <Conversation>[];

          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();
              final participants = List<String>.from(data['participants'] ?? []);
              if (participants.length < 2) continue;
              final otherUserId =
                  participants.firstWhere((id) => id != currentUser.uid, orElse: () => participants.first);

              // Get other user's info
              final otherUserDoc =
                  await _firestore.collection('users').doc(otherUserId).get();
              final otherUserData = otherUserDoc.data() ?? {};

              // Get last message
              ChatMessage? lastMessage;
              if (data['lastMessage'] != null) {
                final msgData = data['lastMessage'] as Map<String, dynamic>;
                final msgTimestamp = msgData['timestamp'];
                final msgImageUrl = msgData['imageUrl'] as String?;
                final msgType = (msgData['messageType'] as String?) ??
                    ((msgImageUrl != null && msgImageUrl.isNotEmpty) ? 'image' : 'text');
                lastMessage = ChatMessage(
                  id: msgData['id'] ?? '',
                  senderId: msgData['senderId'] ?? '',
                  senderName: msgData['senderName'] ?? '',
                  message: msgData['message'] ?? '',
                  messageType: msgType,
                  imageUrl: msgImageUrl,
                  voiceUrl: msgData['voiceUrl'] as String?,
                  voiceDuration: msgData['voiceDuration'] as int?,
                  timestamp: msgTimestamp is Timestamp
                      ? msgTimestamp.toDate()
                      : DateTime.now(),
                  isRead: msgData['isRead'] ?? false,
                );
              }

              final updatedAtRaw = data['updatedAt'];
              final updatedAt = updatedAtRaw is Timestamp
                  ? updatedAtRaw.toDate()
                  : DateTime.now();

              conversations.add(Conversation(
                id: doc.id,
                otherUserId: otherUserId,
                otherUserName: otherUserData['name'] ?? 'Unknown User',
                otherUserImage: otherUserData['imageUrl'],
                lastMessage: lastMessage,
                unreadCount: (data['unreadCount_${currentUser.uid}'] ?? 0) as int,
                updatedAt: updatedAt,
              ));
            } catch (docError) {
              // Skip malformed conversation documents
              continue;
            }
          }

          // Sort conversations by updatedAt in memory
          conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          if (!isClosed) {
            add(_ConversationsUpdated(conversations: conversations));
          }
        } catch (e) {
          if (!isClosed) {
            add(_ConversationsError(message: 'Failed to process conversations: $e'));
          }
        }
      }, onError: (error) {
        if (!isClosed) {
          add(_ConversationsError(message: 'Failed to load conversations: $error'));
        }
      });
    } catch (e) {
      emit(ChatError(message: 'Failed to load conversations: $e'));
    }
  }

  void _onConversationsUpdated(
    _ConversationsUpdated event,
    Emitter<ChatState> emit,
  ) {
    emit(ConversationsLoaded(conversations: event.conversations));
  }

  void _onConversationsError(
    _ConversationsError event,
    Emitter<ChatState> emit,
  ) {
    emit(ChatError(message: event.message));
  }

  Future<void> _onLoadMessagesRequested(
    ChatLoadMessagesRequested event,
    Emitter<ChatState> emit,
  ) async {
    try {
      emit(const ChatLoading());

      // Cancel previous subscription
      await _messagesSubscription?.cancel();

      // Listen to messages in real-time — dispatch events via add()
      _messagesSubscription = _firestore
          .collection('conversations')
          .doc(event.conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .listen((snapshot) {
        try {
          final messages = snapshot.docs.map((doc) {
            final data = doc.data();
            final ts = data['timestamp'];
            final imageUrl = data['imageUrl'] as String?;
            final messageType = (data['messageType'] as String?) ??
                ((imageUrl != null && imageUrl.isNotEmpty) ? 'image' : 'text');
            return ChatMessage(
              id: doc.id,
              senderId: data['senderId'] ?? '',
              senderName: data['senderName'] ?? '',
              message: data['message'] ?? '',
              messageType: messageType,
              imageUrl: imageUrl,
              voiceUrl: data['voiceUrl'] as String?,
              voiceDuration: data['voiceDuration'] as int?,
              timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
              isRead: data['isRead'] ?? false,
            );
          }).toList();

          if (!isClosed) {
            add(_MessagesUpdated(
              conversationId: event.conversationId,
              messages: messages,
            ));
          }
        } catch (e) {
          if (!isClosed) {
            add(_MessagesError(message: 'Failed to process messages: $e'));
          }
        }
      }, onError: (error) {
        if (!isClosed) {
          add(_MessagesError(message: 'Failed to load messages: $error'));
        }
      });
    } catch (e) {
      emit(ChatError(message: 'Failed to load messages: $e'));
    }
  }

  void _onMessagesUpdated(
    _MessagesUpdated event,
    Emitter<ChatState> emit,
  ) {
    emit(MessagesLoaded(
      conversationId: event.conversationId,
      messages: event.messages,
    ));
  }

  void _onMessagesError(
    _MessagesError event,
    Emitter<ChatState> emit,
  ) {
    emit(ChatError(message: event.message));
  }

  Future<void> _onSendMessageRequested(
    ChatSendMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    try {
      emit(MessageSending(conversationId: event.conversationId));

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        emit(const ChatError(message: 'User not authenticated'));
        return;
      }

      // Get current user's name
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      final messageData = {
        'senderId': currentUser.uid,
        'senderName': userName,
        'message': event.message,
        'messageType': event.imageUrl != null ? 'image' : 'text',
        'imageUrl': event.imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Add message to conversation
      final messageRef = await _firestore
          .collection('conversations')
          .doc(event.conversationId)
          .collection('messages')
          .add(messageData);

      // Update conversation with last message
      await _firestore
          .collection('conversations')
          .doc(event.conversationId)
          .update({
        'lastMessage': {
          'id': messageRef.id,
          'senderId': currentUser.uid,
          'senderName': userName,
          'message': event.message,
          'messageType': event.imageUrl != null ? 'image' : 'text',
          'imageUrl': event.imageUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Increment unread count for other user
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(event.conversationId)
          .get();
      final participants =
          List<String>.from(conversationDoc.data()?['participants'] ?? []);
      final otherUserId =
          participants.firstWhere((id) => id != currentUser.uid);

      await _firestore
          .collection('conversations')
          .doc(event.conversationId)
          .update({
        'unreadCount_$otherUserId': FieldValue.increment(1),
      });

      // Message will be received through the stream subscription
    } catch (e) {
      emit(ChatError(message: 'Failed to send message: $e'));
    }
  }

  Future<void> _onMessageReceived(
    ChatMessageReceived event,
    Emitter<ChatState> emit,
  ) async {
    // Messages are received through Firestore streams
    // This event can be used for additional processing if needed
  }

  Future<void> _onMarkAsRead(
    ChatMarkAsRead event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Reset unread count for current user
      await _firestore
          .collection('conversations')
          .doc(event.conversationId)
          .update({
        'unreadCount_${currentUser.uid}': 0,
      });

      // Mark all messages as read
      final messages = await _firestore
          .collection('conversations')
          .doc(event.conversationId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      emit(ChatError(message: 'Failed to mark messages as read: $e'));
    }
  }

  Future<void> _onStartConversation(
    ChatStartConversation event,
    Emitter<ChatState> emit,
  ) async {
    try {
      emit(const ChatLoading());

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        emit(const ChatError(message: 'User not authenticated'));
        return;
      }

      // Check if conversation already exists
      final existingConversations = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      for (var doc in existingConversations.docs) {
        final participants =
            List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(event.otherUserId)) {
          // Conversation exists, emit immediately so caller can navigate directly
          final otherUserDoc =
              await _firestore.collection('users').doc(event.otherUserId).get();
          final otherUserData = otherUserDoc.data() ?? {};

          final conversation = Conversation(
            id: doc.id,
            otherUserId: event.otherUserId,
            otherUserName: event.otherUserName,
            otherUserImage: otherUserData['imageUrl'],
            lastMessage: null,
            unreadCount: 0,
            updatedAt: DateTime.now(),
          );

          emit(ConversationStarted(conversation: conversation));
          add(ChatLoadMessagesRequested(conversationId: doc.id));
          return;
        }
      }

      // Create new conversation
      final conversationData = {
        'participants': [currentUser.uid, event.otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount_${currentUser.uid}': 0,
        'unreadCount_${event.otherUserId}': 0,
      };

      final conversationRef =
          await _firestore.collection('conversations').add(conversationData);

      // Get other user's info
      final otherUserDoc =
          await _firestore.collection('users').doc(event.otherUserId).get();
      final otherUserData = otherUserDoc.data() ?? {};

      final conversation = Conversation(
        id: conversationRef.id,
        otherUserId: event.otherUserId,
        otherUserName: event.otherUserName,
        otherUserImage: otherUserData['imageUrl'],
        lastMessage: null,
        unreadCount: 0,
        updatedAt: DateTime.now(),
      );

      emit(ConversationStarted(conversation: conversation));

      // Load messages for the new conversation
      add(ChatLoadMessagesRequested(conversationId: conversationRef.id));
    } catch (e) {
      emit(ChatError(message: 'Failed to start conversation: $e'));
    }
  }

  @override
  Future<void> close() {
    _conversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    return super.close();
  }
}

// Internal events used to relay Firestore stream data back into the BLoC
class _ConversationsUpdated extends ChatEvent {
  final List<Conversation> conversations;
  const _ConversationsUpdated({required this.conversations});

  @override
  List<Object?> get props => [conversations];
}

class _ConversationsError extends ChatEvent {
  final String message;
  const _ConversationsError({required this.message});

  @override
  List<Object?> get props => [message];
}

class _MessagesUpdated extends ChatEvent {
  final String conversationId;
  final List<ChatMessage> messages;
  const _MessagesUpdated({required this.conversationId, required this.messages});

  @override
  List<Object?> get props => [conversationId, messages];
}

class _MessagesError extends ChatEvent {
  final String message;
  const _MessagesError({required this.message});

  @override
  List<Object?> get props => [message];
}
