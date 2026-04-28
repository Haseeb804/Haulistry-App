import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/utils/cross_platform_image_picker.dart';
import '../../../../core/utils/call_identity_resolver.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/realtime_socket_service.dart';
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
  final RealtimeSocketService _socketService = RealtimeSocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _communicationStatusTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  Timer? _typingDebounceTimer;
  bool _isSending = false;
  bool _isCommunicationAllowed = false;
  bool _isCheckingCommunication = true;
  bool _isOtherUserTyping = false;
  bool _isOtherUserOnline = false;
  bool _typingSentActive = false;
  CallParticipantIdentity? _resolvedOtherUser;
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

  ChatMessage _parseBackendMessage(Map<String, dynamic> row) {
    final messageType = (row['messageType'] as String? ?? 'text').toLowerCase();
    final messageText = (row['messageText'] as String? ?? '').trim();
    final isImage = messageType == 'image' &&
        (messageText.startsWith('http') || messageText.startsWith('data:image/'));
    final isVoice = messageType == 'voice' &&
        (messageText.startsWith('http') || messageText.startsWith('data:audio/'));

    final senderImageUrl = row['senderProfileImageUrl']?.toString();
    return ChatMessage(
      id: row['id']?.toString() ?? '',
      senderId: row['senderId']?.toString() ?? '',
      senderName: row['senderName']?.toString() ?? 'User',
      senderProfileImageUrl: (senderImageUrl?.isNotEmpty == true) ? senderImageUrl : null,
      message: (isImage || isVoice) ? '' : messageText,
      messageType: messageType,
      imageUrl: isImage ? messageText : null,
      voiceUrl: isVoice ? messageText : null,
      voiceDuration: _tryParseInt(row['mediaDuration']) ?? _tryParseInt(row['duration']),
      timestamp: _parseBackendTimestamp(row),
      isRead: row['isRead'] == true,
    );
  }

  @override
  void initState() {
    super.initState();
    _resolveOtherUserIdentity();
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
      if (_useBackendMessaging) {
        unawaited(_emitTyping());
      }
    });

    _checkCommunicationPermission();
    if (widget.bookingId != null && widget.bookingId!.isNotEmpty) {
      _communicationStatusTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _checkCommunicationPermission(),
      );

      _loadBackendMessages();
      unawaited(_setupRealtimeChat());
    }
  }

  Future<void> _setupRealtimeChat() async {
    await _socketService.connect();
    _socketSubscription = _socketService.events.listen((event) {
      final type = event['type']?.toString() ?? '';
      final data = (event['data'] is Map<String, dynamic>)
          ? event['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      if (!_useBackendMessaging || !mounted) return;

      // Real-time fast path: parse the message from the socket payload directly
      // and insert into the list without a round-trip to the API. Falls back to
      // a full reload only on message_status (seen/delivered) or if payload is malformed.
      if (type == 'chat_message' || type == 'chat_sent') {
        final messageMap = (data['message'] is Map<String, dynamic>)
            ? data['message'] as Map<String, dynamic>
            : <String, dynamic>{};
        if (messageMap.isNotEmpty) {
          final msg = _parseBackendMessage(messageMap);
          if (!mounted) return;

          // Deduplicate: skip if we already have this id.
          final alreadyPresent = _backendMessages.any((m) => m.id.isNotEmpty && m.id == msg.id);
          if (!alreadyPresent) {
            setState(() {
              // Append so the list stays oldest-first (matching API ORDER BY createdAt ASC),
              // which is required by the length-1-index access in _buildBackendMessagesView.
              _backendMessages = [..._backendMessages, msg];
            });
            _scrollToBottom();
          }
        } else {
          unawaited(_loadBackendMessages());
        }
      } else if (type == 'message_status') {
        // Update read receipts locally by marking matching messages as read.
        final msgId = data['messageId']?.toString() ?? '';
        final isRead = data['isRead'] == true;
        if (msgId.isNotEmpty && isRead && mounted) {
          setState(() {
            _backendMessages = _backendMessages.map((m) {
              return m.id == msgId ? m.copyWith(isRead: true) : m;
            }).toList();
          });
        }
      }

      if (type == 'typing') {
        final fromUserId = data['fromUserId']?.toString() ?? '';
        final bookingId = data['bookingId']?.toString() ?? '';
        if (fromUserId == widget.otherUserId && bookingId == (widget.bookingId ?? '')) {
          if (!mounted) return;
          setState(() {
            _isOtherUserTyping = data['isTyping'] == true;
          });
        }
      }

      if (type == 'presence_state' || type == 'presence_update') {
        final targetUserId = data['userId']?.toString() ?? '';
        if (targetUserId == widget.otherUserId) {
          if (!mounted) return;
          setState(() {
            _isOtherUserOnline = data['online'] == true;
          });
        }
      }

      if (type == 'call_incoming') {
        final bookingId = data['bookingId']?.toString() ?? '';
        if (bookingId.isNotEmpty && bookingId == (widget.bookingId ?? '')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incoming call...')),
          );
        }
      }
    });

    await _socketService.send('presence_query', {
      'targetUserId': widget.otherUserId,
    });
  }

  Future<void> _emitTyping() async {
    if (!_useBackendMessaging || !_socketService.isConnected) return;

    final text = _messageController.text.trim();
    final shouldBeTyping = text.isNotEmpty;

    if (shouldBeTyping != _typingSentActive) {
      _typingSentActive = shouldBeTyping;
      await _socketService.send('typing', {
        'receiverId': widget.otherUserId,
        'bookingId': widget.bookingId,
        'isTyping': shouldBeTyping,
      });
    }

    _typingDebounceTimer?.cancel();
    if (shouldBeTyping) {
      _typingDebounceTimer = Timer(const Duration(seconds: 2), () async {
        if (!_typingSentActive) return;
        _typingSentActive = false;
        await _socketService.send('typing', {
          'receiverId': widget.otherUserId,
          'bookingId': widget.bookingId,
          'isTyping': false,
        });
      });
    }
  }

  Future<void> _resolveOtherUserIdentity() async {
    final resolved = await CallIdentityResolver.resolveParticipant(
      userId: widget.otherUserId,
      fallbackName: widget.otherUserName,
      fallbackRole: widget.otherUserRole,
      fallbackProfileImageUrl: widget.otherUserImage,
      defaultLabel: 'User',
    );

    if (!mounted) return;
    setState(() {
      _resolvedOtherUser = resolved;
    });
  }

  String get _displayOtherUserName => CallIdentityResolver.resolveDisplayName(
        preferredName: _resolvedOtherUser?.displayName,
        fallbackName: widget.otherUserName,
        defaultLabel: 'User',
      );

  String get _displayOtherUserRole => CallIdentityResolver.resolveRole(
        preferredRole: _resolvedOtherUser?.role,
        fallbackRole: widget.otherUserRole,
      );

  String? get _displayOtherUserImage => CallIdentityResolver.resolveProfileImageUrl(
        preferredImageUrl: _resolvedOtherUser?.profileImageUrl,
        fallbackImageUrl: widget.otherUserImage,
      );

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

  Future<void> _loadBackendMessages({int retryAttempt = 0}) async {
    if (!_useBackendMessaging || !mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (_isBackendMessagesLoading) return;
    _isBackendMessagesLoading = true;

    try {
      final response = await ApiService.instance.get(
        ApiEndpoints.conversationMessages(currentUser.uid, widget.otherUserId, widget.bookingId!),
      );

      final rows = (response['messages'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final parsed = rows.map(_parseBackendMessage).toList();

      if (!mounted) return;

      // Merge API response (oldest-first) with any socket-pushed messages that
      // haven't been confirmed by the server yet. Unsaved messages go at the end
      // to preserve oldest-first ordering used by _buildBackendMessagesView.
      final existingUnsaved = _backendMessages
          .where((m) => m.id.isNotEmpty && !parsed.any((p) => p.id == m.id))
          .toList();
      final merged = [...parsed, ...existingUnsaved];

      setState(() {
        _backendMessages = merged;
        _backendMessagesError = null;
      });
    } catch (e) {
      // Silent retry with backoff: transient network errors shouldn't scare the user.
      if (retryAttempt < 2) {
        _isBackendMessagesLoading = false;
        await Future<void>.delayed(Duration(milliseconds: 400 * (retryAttempt + 1)));
        return _loadBackendMessages(retryAttempt: retryAttempt + 1);
      }
      if (!mounted) return;
      // Keep existing messages visible; just record the error without wiping the list.
      _backendMessagesError = e.toString();
    } finally {
      _isBackendMessagesLoading = false;
    }
  }

  @override
  void dispose() {
    _communicationStatusTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _socketSubscription?.cancel();
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
      final encoded = base64Encode(audioBytes);
      final voiceDataUrl = 'data:audio/m4a;base64,$encoded';

      await _socketService.sendWithAck('chat_send', {
        'receiverId': widget.otherUserId,
        'bookingId': widget.bookingId,
        'messageText': voiceDataUrl,
        'messageType': 'voice',
        'mediaDuration': duration,
        'clientMessageId': '${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
      });
      // The server will echo a chat_sent event that the socket listener already
      // appends to _backendMessages. No separate reload needed.
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

    context.read<CallBloc>().add(
          InitiateCallRequested(
            receiverId: widget.otherUserId,
            receiverName: _displayOtherUserName,
            receiverRole: _displayOtherUserRole,
            receiverProfileImageUrl: _displayOtherUserImage,
            bookingId: bookingId,
            callType: callType,
          ),
        );
    // Navigation is handled by the BlocListener in main.dart when CallInitiated fires.
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
        final ext = _detectImageFormat(image.bytes).replaceFirst('.', '').toLowerCase();
        final mime = ext == 'png'
            ? 'image/png'
            : ext == 'gif'
                ? 'image/gif'
                : ext == 'webp'
                    ? 'image/webp'
                    : ext == 'bmp'
                        ? 'image/bmp'
                        : 'image/jpeg';
        final encoded = base64Encode(image.bytes);
        final imageDataUrl = 'data:$mime;base64,$encoded';

        await _socketService.sendWithAck('chat_send', {
          'receiverId': widget.otherUserId,
          'bookingId': widget.bookingId,
          'messageText': imageDataUrl,
          'messageType': 'image',
          'clientMessageId': '${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
        });
        // chat_sent socket event appends the image to _backendMessages.
        _scrollToBottom();
      } else {
        throw Exception('Image sharing is only supported via booking chat with Neo4j backend');
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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _messageController.clear();
    final clientMessageId = '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}';

    // Optimistic display: show message immediately before server confirms.
    final optimisticId = 'pending_$clientMessageId';
    final optimisticMsg = ChatMessage(
      id: optimisticId,
      senderId: currentUser.uid,
      senderName: currentUser.displayName ?? 'Me',
      message: message,
      timestamp: DateTime.now(),
      isRead: false,
    );
    // Append at end — list is oldest-first, so new messages belong at the tail.
    setState(() {
      _backendMessages = [..._backendMessages, optimisticMsg];
    });
    _scrollToBottom();

    try {
      final ack = await _socketService.sendWithAck('chat_send', {
        'receiverId': widget.otherUserId,
        'bookingId': widget.bookingId,
        'messageText': message,
        'messageType': 'text',
        'clientMessageId': clientMessageId,
      });

      if (!mounted) return;

      if (ack != null && ack['ok'] == true) {
        final data = (ack['data'] is Map) ? Map<String, dynamic>.from(ack['data'] as Map) : <String, dynamic>{};
        final messageMap = (data['message'] is Map)
            ? Map<String, dynamic>.from(data['message'] as Map)
            : <String, dynamic>{};
        if (messageMap.isNotEmpty) {
          final parsed = _parseBackendMessage(messageMap);
          setState(() {
            // Remove optimistic placeholder; append confirmed message unless the
            // chat_sent socket event already inserted it.
            final withoutOptimistic = _backendMessages.where((m) => m.id != optimisticId).toList();
            if (!withoutOptimistic.any((m) => m.id.isNotEmpty && m.id == parsed.id)) {
              _backendMessages = [...withoutOptimistic, parsed];
            } else {
              _backendMessages = withoutOptimistic;
            }
          });
          _scrollToBottom();
          return;
        }
      }

      // Fallback: remove optimistic message and reload from backend.
      setState(() {
        _backendMessages = _backendMessages.where((m) => m.id != optimisticId).toList();
      });
      await _loadBackendMessages();
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      // Remove optimistic message and restore input for manual retry.
      setState(() {
        _backendMessages = _backendMessages.where((m) => m.id != optimisticId).toList();
      });
      _messageController.text = message;
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
                  foregroundImage: ImageHelper.providerFor(_displayOtherUserImage),
                  onForegroundImageError: _displayOtherUserImage != null ? (_, __) {} : null,
                  child: Text(
                    _displayOtherUserName.isNotEmpty ? _displayOtherUserName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayOtherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isOtherUserTyping
                        ? 'Typing...'
                        : (_displayOtherUserRole.isNotEmpty && _displayOtherUserRole != AppConstants.roleUser
                            ? _displayOtherUserRole[0].toUpperCase() + _displayOtherUserRole.substring(1)
                            : (_isOtherUserOnline ? 'Online' : 'Offline')),
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
              onPressed: () {},
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

class _SenderAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;

  const _SenderAvatar({required this.imageUrl, required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    final provider = ImageHelper.providerFor(imageUrl);
    if (provider != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
        foregroundImage: provider,
        onForegroundImageError: (_, __) {},
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: AppTheme.secondaryColor,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: AppTheme.secondaryColor,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  Uint8List? _decodeDataImage(String value) {
    if (!value.startsWith('data:image/')) return null;
    final commaIndex = value.indexOf(',');
    if (commaIndex < 0 || commaIndex >= value.length - 1) return null;
    try {
      return base64Decode(value.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat.jm().format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isCurrentUser = message.senderId == currentUserId;

    final decodedImageBytes = message.imageUrl != null ? _decodeDataImage(message.imageUrl!) : null;

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
              child: _SenderAvatar(
                imageUrl: message.senderProfileImageUrl,
                name: message.senderName,
                radius: 14,
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
                      child: decodedImageBytes != null
                          ? Image.memory(
                              decodedImageBytes,
                              width: 200,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
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
