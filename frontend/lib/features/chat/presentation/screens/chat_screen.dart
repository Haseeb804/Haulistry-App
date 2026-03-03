import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/cross_platform_image_picker.dart';
import '../../../../core/services/api_service.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../../../call/presentation/bloc/call_bloc.dart';
import '../../../call/presentation/bloc/call_event.dart';
import '../../../call/presentation/widgets/voice_message_recorder.dart';
import '../../../call/presentation/widgets/voice_message_player.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;
  final String? otherUserRole;
  final String? bookingId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
    this.otherUserRole,
    this.bookingId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isRecordingVoice = false;

  @override
  void initState() {
    super.initState();
    context
        .read<ChatBloc>()
        .add(ChatLoadMessagesRequested(conversationId: widget.conversationId));
    context
        .read<ChatBloc>()
        .add(ChatMarkAsRead(conversationId: widget.conversationId));
    
    // Listen for text changes to toggle between send and voice button
    _messageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _uploadAndSendVoiceMessage(File audioFile, int duration) async {
    try {
      setState(() => _isSending = true);

      // Upload audio to Firebase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ref = FirebaseStorage.instance
          .ref()
          .child('voice_messages')
          .child(fileName);

      await ref.putFile(audioFile);
      final audioUrl = await ref.getDownloadURL();

      // Send to backend
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || widget.bookingId == null) {
        throw Exception('User not authenticated or booking ID missing');
      }

      final response = await ApiService.instance.post(
        '/calls/voice-message/upload',
        {
          'senderId': user.uid,
          'receiverId': widget.otherUserId,
          'bookingId': widget.bookingId,
          'audioUrl': audioUrl,
          'duration': duration,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to send voice message');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Voice message sent'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice message: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _initiateCall(String callType) {
    // Use booking ID if available, otherwise use a placeholder
    final bookingId = widget.bookingId ?? 'chat_call_${DateTime.now().millisecondsSinceEpoch}';

    // Determine the receiver's role for display
    final receiverRole = widget.otherUserRole ?? 'user';

    context.read<CallBloc>().add(
          InitiateCallRequested(
            receiverId: widget.otherUserId,
            receiverName: widget.otherUserName,
            receiverRole: receiverRole,
            bookingId: bookingId,
            callType: callType,
          ),
        );

    // Navigate to outgoing call screen
    context.push('/call/outgoing', extra: {
      'callId': 'pending', // Will be set by bloc
      'receiverName': widget.otherUserName,
      'receiverRole': receiverRole,
      'callType': callType,
    });
  }

  Future<void> _uploadImageBytes(Uint8List imageBytes, String fileName) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child('$fileName.jpg');

      await ref.putData(imageBytes);
      final imageUrl = await ref.getDownloadURL();

      if (mounted) {
        context.read<ChatBloc>().add(
              ChatSendMessageRequested(
                conversationId: widget.conversationId,
                message: '',
                imageUrl: imageUrl,
              ),
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final image = await CrossPlatformImagePicker.pickFromGallery();

    if (image != null) {
      setState(() => _isSending = true);

      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      await _uploadImageBytes(image.bytes, fileName);

      setState(() => _isSending = false);
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    context.read<ChatBloc>().add(
          ChatSendMessageRequested(
            conversationId: widget.conversationId,
            message: message,
          ),
        );

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  backgroundImage: widget.otherUserImage != null
                      ? NetworkImage(widget.otherUserImage!)
                      : null,
                  child: widget.otherUserImage == null
                      ? Text(
                          widget.otherUserName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.otherUserRole != null && widget.otherUserRole!.isNotEmpty && widget.otherUserRole != 'user'
                        ? widget.otherUserRole![0].toUpperCase() + widget.otherUserRole!.substring(1)
                        : 'Online',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              gradient: AppTheme.secondaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 22),
              onPressed: () => _initiateCall('voice'),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
              onPressed: () => _initiateCall('video'),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 22),
              onPressed: () {
                // TODO: Show chat options
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<ChatBloc, ChatState>(
              listener: (context, state) {
                if (state is MessageSent) {
                  _scrollToBottom();
                }
              },
              builder: (context, state) {
                if (state is ChatLoading && state is! MessagesLoaded) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  );
                }

                if (state is ChatError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppTheme.errorColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            context.read<ChatBloc>().add(
                                  ChatLoadMessagesRequested(
                                    conversationId: widget.conversationId,
                                  ),
                                );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Retry',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (state is MessagesLoaded &&
                    state.conversationId == widget.conversationId) {
                  if (state.messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient.scale(0.3),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 56,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Start the conversation!',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return _MessageBubble(message: message);
                    },
                  );
                }

                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final isEmpty = _messageController.text.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -4),
            blurRadius: 12,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                icon: const Icon(Icons.image_rounded, color: Colors.white, size: 22),
                onPressed: _isSending ? null : _pickAndSendImage,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            isEmpty
                ? VoiceMessageRecorder(
                    onRecordingComplete: _uploadAndSendVoiceMessage,
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat.jm().format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isCurrentUser = message.senderId == currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: AppTheme.secondaryGradient,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                child: Text(
                  message.senderName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ),
            ),
          if (!isCurrentUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isCurrentUser ? AppTheme.primaryGradient : null,
                color: isCurrentUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isCurrentUser ? 20 : 6),
                  bottomRight: Radius.circular(isCurrentUser ? 6 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isCurrentUser
                        ? AppTheme.primaryColor.withOpacity(0.2)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        message.imageUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (message.imageUrl != null && message.message.isNotEmpty)
                    const SizedBox(height: 8),
                  if (message.message.isNotEmpty)
                    Text(
                      message.message,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimestamp(message.timestamp),
                        style: TextStyle(
                          color: isCurrentUser
                              ? Colors.white.withOpacity(0.7)
                              : AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
