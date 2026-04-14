import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
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
  Timer? _communicationStatusTimer;
  Timer? _backendMessagesPollingTimer;
  bool _isSending = false;
  bool _isCommunicationAllowed = false;
  bool _isCheckingCommunication = true;
  bool _isBackendMessagesLoading = false;
  String? _backendMessagesError;
  List<ChatMessage> _backendMessages = const [];

  static const Set<String> _activeStatuses = {
    AppConstants.statusConfirmed,
    AppConstants.statusAccepted,
    AppConstants.statusActive,
    AppConstants.statusProviderArriving,
    AppConstants.statusProviderArrived,
    AppConstants.statusInProgress,
  };

  bool get _useBackendMessaging => widget.bookingId != null && widget.bookingId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_useBackendMessaging) {
      context
        .read<ChatBloc>()
        .add(ChatLoadMessagesRequested(conversationId: widget.conversationId));
      context
        .read<ChatBloc>()
        .add(ChatMarkAsRead(conversationId: widget.conversationId));
    }
    
    // Listen for text changes to toggle between send and voice button
    _messageController.addListener(() {
      setState(() {});
    });

    _checkCommunicationPermission();
    if (widget.bookingId != null && widget.bookingId!.isNotEmpty) {
      _communicationStatusTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _checkCommunicationPermission(),
      );

      _loadBackendMessages();
      _backendMessagesPollingTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _loadBackendMessages(),
      );
    }
  }

  Future<void> _checkCommunicationPermission() async {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isCommunicationAllowed = false;
        _isCheckingCommunication = false;
      });
      return;
    }

    try {
      final response = await ApiService.instance.getBooking(widget.bookingId!);
      final booking = response['booking'] as Map<String, dynamic>?;
      final status = (booking?['status'] as String? ?? '').toLowerCase();

      if (!mounted) return;
      setState(() {
        _isCommunicationAllowed = _activeStatuses.contains(status);
        _isCheckingCommunication = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCommunicationAllowed = false;
        _isCheckingCommunication = false;
      });
    }
  }

  void _showCommunicationBlockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Communication is only available while service is active.'),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  DateTime _parseBackendTimestamp(Map<String, dynamic> message) {
    final raw = message['createdAt'] ?? message['timestamp'] ?? message['updatedAt'];
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }

  int? _tryParseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _loadBackendMessages() async {
    if (!_useBackendMessaging || !mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (_isBackendMessagesLoading) return;
    _isBackendMessagesLoading = true;

    try {
      final response = await ApiService.instance.get(
        ApiEndpoints.conversationMessages(currentUser.uid, widget.otherUserId, widget.bookingId!),
      );

      if (response['success'] == true) {
        final rows = (response['messages'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();

        final parsed = rows.map((row) {
          final messageType = (row['messageType'] as String? ?? 'text').toLowerCase();
          final messageText = (row['messageText'] as String? ?? '').trim();
          final isImage = messageType == 'image' && messageText.startsWith('http');
          final isVoice = messageType == 'voice' && messageText.startsWith('http');

          return ChatMessage(
            id: row['id']?.toString() ?? '',
            senderId: row['senderId']?.toString() ?? '',
            senderName: row['senderName']?.toString() ?? 'User',
            message: (isImage || isVoice) ? '' : messageText,
            messageType: messageType,
            imageUrl: isImage ? messageText : null,
            voiceUrl: isVoice ? messageText : null,
            voiceDuration: _tryParseInt(row['mediaDuration']) ?? _tryParseInt(row['duration']),
            timestamp: _parseBackendTimestamp(row),
            isRead: row['isRead'] == true,
          );
        }).toList();

        if (!mounted) return;
        setState(() {
          _backendMessages = parsed;
          _backendMessagesError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _backendMessagesError = e.toString();
      });
    } finally {
      _isBackendMessagesLoading = false;
    }
  }

  @override
  void dispose() {
    _communicationStatusTimer?.cancel();
    _backendMessagesPollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _uploadAndSendVoiceMessage(File audioFile, int duration) async {
    try {
      if (!_isCommunicationAllowed) {
        _showCommunicationBlockedMessage();
        return;
      }

      setState(() => _isSending = true);

      // Send to backend
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || widget.bookingId == null) {
        throw Exception('User not authenticated or booking ID missing');
      }

      final audioBytes = await audioFile.readAsBytes();
      final fileName = audioFile.path.split(RegExp(r'[\\/]')).last;
      
      // Determine audio MIME type based on filename
      String audioMimeType = 'audio/m4a'; // Default
      if (fileName.toLowerCase().endsWith('.mp3')) {
        audioMimeType = 'audio/mpeg';
      } else if (fileName.toLowerCase().endsWith('.wav')) {
        audioMimeType = 'audio/wav';
      } else if (fileName.toLowerCase().endsWith('.ogg')) {
        audioMimeType = 'audio/ogg';
      } else if (fileName.toLowerCase().endsWith('.m4a')) {
        audioMimeType = 'audio/aac';
      }

      final response = await ApiService.instance.postMultipart(
        ApiEndpoints.messageUploadVoice,
        fields: {
          'senderId': user.uid,
          'receiverId': widget.otherUserId,
          'bookingId': widget.bookingId!,
          'duration': duration.toString(),
        },
        fileField: 'audio',
        fileBytes: audioBytes,
        fileName: fileName.isNotEmpty
            ? fileName
            : '${DateTime.now().millisecondsSinceEpoch}.m4a',
        contentType: audioMimeType,
      );

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to send voice message');
      }

      await _loadBackendMessages();
      _scrollToBottom();

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
    if (!_isCommunicationAllowed || widget.bookingId == null || widget.bookingId!.isEmpty) {
      _showCommunicationBlockedMessage();
      return;
    }

    final bookingId = widget.bookingId!;

    // Determine the receiver's role for display
    final receiverRole = widget.otherUserRole ?? AppConstants.roleUser;

    context.read<CallBloc>().add(
          InitiateCallRequested(
            receiverId: widget.otherUserId,
            receiverName: widget.otherUserName,
            receiverRole: receiverRole,
            receiverProfileImageUrl: widget.otherUserImage,
            bookingId: bookingId,
            callType: callType,
          ),
        );

    // Navigate to outgoing call screen
    context.push(AppRoutes.callOutgoing, extra: {
      'callId': 'pending', // Will be set by bloc
      'receiverName': widget.otherUserName,
      'receiverRole': receiverRole,
      'receiverProfileImageUrl': widget.otherUserImage,
      'callType': callType,
    });
  }

  /// Detect image format from file bytes (magic numbers)
  String _detectImageFormat(Uint8List bytes) {
    if (bytes.length < 4) return '.jpg'; // Default if too small
    
    // Check PNG signature
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return '.png';
    }
    // Check JPEG signature
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return '.jpg';
    }
    // Check GIF signature
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return '.gif';
    }
    // Check WebP signature (RIFF....WEBP)
    if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return '.webp';
    }
    // Check BMP signature
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return '.bmp';
    }
    return '.jpg'; // Default fallback
  }

  String _generateImageFilename(CrossPlatformImage image) {
    if (image.name.isNotEmpty) {
      return image.name;
    }
    // Generate filename with detected format instead of always .jpg
    final format = _detectImageFormat(image.bytes);
    return '${DateTime.now().millisecondsSinceEpoch}$format';
  }

  Future<void> _uploadAndSendImage(CrossPlatformImage image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (_useBackendMessaging) {
        final filename = _generateImageFilename(image);
        final response = await ApiService.instance.postMultipart(
          ApiEndpoints.messageUploadImage,
          fields: {
            'senderId': user.uid,
            'receiverId': widget.otherUserId,
            'bookingId': widget.bookingId!,
          },
          fileField: 'image',
          fileBytes: image.bytes,
          fileName: filename,
        );

        if (response['success'] != true) {
          throw Exception(response['message'] ?? 'Failed to send image');
        }
        await _loadBackendMessages();
        _scrollToBottom();
      } else {
        final filename = _generateImageFilename(image);
        final ref = FirebaseStorage.instance
            .ref()
            .child('chat_images')
            .child(filename);

        await ref.putData(image.bytes);
        final imageUrl = await ref.getDownloadURL();

        if (!mounted) return;

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
    if (!_isCommunicationAllowed) {
      _showCommunicationBlockedMessage();
      return;
    }

    final image = await CrossPlatformImagePicker.pickFromGallery();

    if (image != null) {
      setState(() => _isSending = true);

      await _uploadAndSendImage(image);

      setState(() => _isSending = false);
    }
  }

  void _sendMessage() {
    if (!_isCommunicationAllowed) {
      _showCommunicationBlockedMessage();
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    if (_useBackendMessaging) {
      _sendMessageViaBackend(message);
      return;
    }

    context.read<ChatBloc>().add(
          ChatSendMessageRequested(
            conversationId: widget.conversationId,
            message: message,
          ),
        );

    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _sendMessageViaBackend(String message) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final response = await ApiService.instance.post(ApiEndpoints.messageSend, {
        'senderId': currentUser.uid,
        'receiverId': widget.otherUserId,
        'bookingId': widget.bookingId,
        'messageText': message,
        'messageType': 'text',
      });

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to send message');
      }

      _messageController.clear();
      await _loadBackendMessages();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
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
            icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary, size: 20),
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
                  backgroundImage: ImageHelper.providerFor(widget.otherUserImage),
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
                    widget.otherUserRole != null && widget.otherUserRole!.isNotEmpty && widget.otherUserRole != AppConstants.roleUser
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
              onPressed: _isCheckingCommunication ? null : () => _initiateCall(AppConstants.callTypeVoice),
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
              onPressed: _isCheckingCommunication ? null : () => _initiateCall(AppConstants.callTypeVideo),
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
          if (_isCheckingCommunication)
            const LinearProgressIndicator(minHeight: 2)
          else if (!_isCommunicationAllowed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.errorColor.withOpacity(0.1),
              child: const Text(
                'Service is not active. Messaging and calling are disabled.',
                style: TextStyle(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _useBackendMessaging
                ? _buildBackendMessagesView()
                : BlocConsumer<ChatBloc, ChatState>(
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
                onPressed: _isSending || _isCheckingCommunication || !_isCommunicationAllowed
                    ? null
                    : _pickAndSendImage,
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
                  enabled: !_isCheckingCommunication && _isCommunicationAllowed,
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
                ? IgnorePointer(
                    ignoring: _isCheckingCommunication || !_isCommunicationAllowed,
                    child: Opacity(
                      opacity: _isCheckingCommunication || !_isCommunicationAllowed ? 0.5 : 1,
                      child: VoiceMessageRecorder(
                        onRecordingComplete: _uploadAndSendVoiceMessage,
                      ),
                    ),
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
                      onPressed: _isSending || _isCheckingCommunication || !_isCommunicationAllowed
                          ? null
                          : _sendMessage,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackendMessagesView() {
    if (_backendMessagesError != null && _backendMessages.isEmpty) {
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
              'Failed to load messages',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadBackendMessages,
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

    if (_backendMessages.isEmpty) {
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
      itemCount: _backendMessages.length,
      itemBuilder: (context, index) {
        final message = _backendMessages[_backendMessages.length - 1 - index];
        return _MessageBubble(message: message);
      },
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
                  if (message.voiceUrl != null) ...[
                    SizedBox(
                      width: 220,
                      child: VoiceMessagePlayer(
                        audioUrl: message.voiceUrl!,
                        duration: message.voiceDuration ?? 0,
                        isSentByMe: isCurrentUser,
                      ),
                    ),
                  ],
                  if ((message.imageUrl != null || message.voiceUrl != null) && message.message.isNotEmpty)
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
