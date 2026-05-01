import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/call_minimize_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/realtime_socket_service.dart';
import '../../../../core/services/webrtc_call_service.dart';
import '../../../../core/utils/call_identity_resolver.dart';
import 'call_event.dart';
import 'call_state.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  final WebRTCCallService _callService;
  final RealtimeSocketService _socketService;
  final ApiService _apiService;
  final FirebaseAuth _auth;

  StreamSubscription? _callStateSubscription;
  StreamSubscription? _remoteUserSubscription;
  StreamSubscription? _socketSubscription;
  StreamSubscription? _notificationSubscription;

  DateTime? _callStartTime;
  String? _currentCallId;
  String? _currentBookingId;
  String _otherUserId = '';
  String _otherUserName = '';
  String _otherUserRole = AppConstants.roleUser;
  String? _otherUserProfileImageUrl;
  String _currentCallType = AppConstants.callTypeVoice;
  int? _pendingRemoteUid;
  Map<String, dynamic>? _currentSignalData;
  bool _isLocalParticipantConnected = false;

  CallBloc({
    WebRTCCallService? callService,
    RealtimeSocketService? socketService,
    ApiService? apiService,
    FirebaseAuth? auth,
  })  : _callService = callService ?? WebRTCCallService(),
        _socketService = socketService ?? RealtimeSocketService(),
        _apiService = apiService ?? ApiService.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(const CallInitial()) {
    on<InitiateCallRequested>(_onInitiateCallRequested);
    on<AnswerCallRequested>(_onAnswerCallRequested);
    on<CallAnswerAcceptedByReceiver>(_onCallAnswerAcceptedByReceiver);
    on<EndCallRequested>(_onEndCallRequested);
    on<RejectCallRequested>(_onRejectCallRequested);
    on<MissedCallReported>(_onMissedCallReported);
    on<ToggleMuteRequested>(_onToggleMuteRequested);
    on<ToggleSpeakerRequested>(_onToggleSpeakerRequested);
    on<ToggleVideoRequested>(_onToggleVideoRequested);
    on<SwitchCameraRequested>(_onSwitchCameraRequested);
    on<CallStateChanged>(_onCallStateChanged);
    on<RemoteUserJoined>(_onRemoteUserJoined);
    on<RemoteUserLeft>(_onRemoteUserLeft);
    on<IncomingCallReceived>(_onIncomingCallReceived);
    on<LoadCallHistoryRequested>(_onLoadCallHistoryRequested);
    on<RemoteCallStatusUpdated>(_onRemoteCallStatusUpdated);

    _initializeRealtime();
    _setupNotificationListener();
  }

  Future<void> _initializeRealtime() async {
    await _socketService.connect();
    await _callService.initialize();

    _callStateSubscription = _callService.callStateStream.listen((callState) {
      add(CallStateChanged(_mapMediaState(callState)));
    });

    _remoteUserSubscription = _callService.remoteUserStream.listen((remoteUser) {
      if (remoteUser.isJoined) {
        add(RemoteUserJoined(remoteUser.uid));
      } else {
        add(RemoteUserLeft(remoteUser.uid));
      }
    });

    _socketSubscription = _socketService.events.listen((event) {
      final type = event['type']?.toString() ?? '';
      final data = (event['data'] is Map<String, dynamic>)
          ? event['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      if (type == 'call_incoming') {
        add(IncomingCallReceived(
          callId: data['callId']?.toString() ?? '',
          callerId: data['callerId']?.toString() ?? '',
          callerName: data['callerName']?.toString() ?? 'User',
          callerRole: data['callerRole']?.toString() ?? AppConstants.roleUser,
          callerProfileImageUrl: data['callerProfileImageUrl']?.toString(),
          callType: data['callType']?.toString() ?? AppConstants.callTypeVoice,
          signalData: (data['signalData'] is Map<String, dynamic>)
              ? data['signalData'] as Map<String, dynamic>
              : <String, dynamic>{},
          bookingId: data['bookingId']?.toString() ?? '',
        ));
      }

      if (type == 'call_accept') {
        final callId = data['callId']?.toString() ?? '';
        if (callId.isEmpty) return;
        // Allow if callId matches, OR if we're still on 'pending' (API hasn't
        // responded yet but receiver answered very fast).
        if (callId != _currentCallId && _currentCallId != 'pending') return;

        add(CallAnswerAcceptedByReceiver(
          callId: callId,
          callType: _currentCallType,
          signalData: _currentSignalData ?? const <String, dynamic>{},
        ));
        return;
      }

      if (type == 'call_reject' || type == 'call_end') {
        final callId = data['callId']?.toString() ?? '';
        if (callId.isEmpty) return;
        if (callId != _currentCallId && _currentCallId != 'pending') return;

        add(RemoteCallStatusUpdated(
          callId: callId,
          status: type == 'call_reject' ? AppConstants.callStatusRejected : AppConstants.callStatusEnded,
          duration: int.tryParse(data['duration']?.toString() ?? '0') ?? 0,
        ));
        return;
      }

      if (type == 'call_status') {
        final status = data['status']?.toString().toLowerCase() ?? '';
        final callId = data['callId']?.toString() ?? '';
        if (callId.isEmpty || callId != _currentCallId) return;

        if (status == 'answered' && state is CallInitiated) {
          add(CallAnswerAcceptedByReceiver(
            callId: callId,
            callType: _currentCallType,
            signalData: _currentSignalData ?? const <String, dynamic>{},
          ));
          return;
        }

        if (status == AppConstants.callStatusRejected ||
            status == AppConstants.callStatusMissed ||
            status == AppConstants.callStatusEnded) {
          if (state is CallEnded || state is CallError) return;
          add(EndCallRequested(
            callId: callId,
            duration: int.tryParse(data['duration']?.toString() ?? '0') ?? 0,
          ));
        }
      }
    });
  }

  void _setupNotificationListener() {
    _notificationSubscription = NotificationService().notificationStream.listen((data) {
      final type = data['type']?.toString();
      if (type != NotificationService.notificationTypeCall) return;

      final callId = data['callId']?.toString() ?? '';
      final callerId = data['callerId']?.toString() ?? '';
      if (callId.isEmpty || callerId.isEmpty) return;

      final signalData =
          (data['signalData'] is Map<String, dynamic>) ? data['signalData'] as Map<String, dynamic> : <String, dynamic>{};

      add(IncomingCallReceived(
        callId: callId,
        callerId: callerId,
        callerName: data['callerName']?.toString() ?? 'User',
        callerRole: data['callerRole']?.toString() ?? AppConstants.roleUser,
        callerProfileImageUrl: data['callerProfileImageUrl']?.toString(),
        callType: data['callType']?.toString() ?? AppConstants.callTypeVoice,
        signalData: signalData,
      ));
    });
  }

  void _emitConnectedIfReady(Emitter<CallState> emit) {
    if (!_isLocalParticipantConnected) {
      return;
    }
    if (state is CallConnected) {
      return;
    }

    String callId = _currentCallId ?? '';
    String callType = _currentCallType;
    String otherUserName = _otherUserName;
    String otherUserRole = _otherUserRole;
    String? otherUserProfileImageUrl = _otherUserProfileImageUrl;
    bool isMuted = false;
    bool isVideoOn = true;

    if (state is CallConnecting) {
      final connectingState = state as CallConnecting;
      callId = connectingState.callId;
      callType = connectingState.callType;
      otherUserName = connectingState.otherUserName;
      otherUserRole = connectingState.otherUserRole;
      otherUserProfileImageUrl = connectingState.otherUserProfileImageUrl;
      // Carry over any mute/video toggle made during the connecting phase.
      isMuted = connectingState.isMuted;
      isVideoOn = connectingState.isVideoOn;
    } else if (state is CallInitiated) {
      final initiatedState = state as CallInitiated;
      callId = initiatedState.callId;
      callType = initiatedState.callType;
      otherUserName = initiatedState.receiverName;
      otherUserRole = initiatedState.receiverRole;
      otherUserProfileImageUrl = initiatedState.receiverProfileImageUrl;
    }

    // 'pending' means the API hasn't confirmed the call ID yet — do not
    // transition to Connected until the real ID is in place.
    if (callId.isEmpty || callId == 'pending') {
      return;
    }

    _callStartTime ??= DateTime.now();

    // Video calls default to speakerphone (user looks at screen).
    // Voice calls default to earpiece (conventional phone behaviour).
    final defaultSpeaker = callType == AppConstants.callTypeVideo;
    unawaited(_callService.enableSpeakerphone(defaultSpeaker));

    emit(CallConnected(
      callId: callId,
      callType: callType,
      connectedAt: _callStartTime!,
      otherUserName: otherUserName,
      otherUserRole: otherUserRole,
      otherUserProfileImageUrl: otherUserProfileImageUrl,
      remoteUid: _pendingRemoteUid,
      isSpeakerOn: defaultSpeaker,
      isMuted: isMuted,
      isVideoOn: isVideoOn,
    ));
  }

  CallConnectionState _mapMediaState(CallMediaState mediaState) {
    switch (mediaState) {
      case CallMediaState.connecting:
        return CallConnectionState.connecting;
      case CallMediaState.connected:
        return CallConnectionState.connected;
      case CallMediaState.disconnected:
        return CallConnectionState.disconnected;
      case CallMediaState.error:
        return CallConnectionState.error;
      default:
        return CallConnectionState.idle;
    }
  }

  Future<void> _onInitiateCallRequested(
    InitiateCallRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        emit(const CallError(message: 'User not authenticated'));
        return;
      }

      final callerRole = event.receiverRole == AppConstants.roleProvider
          ? AppConstants.roleSeeker
          : AppConstants.roleProvider;

      // ── Step 1: Show outgoing call screen IMMEDIATELY (no network wait) ──
      // WhatsApp-style: UI appears on button press; API failure pops it with an error.
      _currentCallType = event.callType;
      _otherUserId = event.receiverId;
      _otherUserName = event.receiverName;
      _otherUserRole = event.receiverRole;
      _otherUserProfileImageUrl = event.receiverProfileImageUrl;
      _currentBookingId = event.bookingId.isNotEmpty ? event.bookingId : null;
      _isLocalParticipantConnected = false;
      _pendingRemoteUid = null;

      // Pre-cache identity so the outgoing screen renders avatar instantly.
      CallIdentityResolver.preCacheIdentity(
        userId: event.receiverId,
        displayName: event.receiverName,
        role: event.receiverRole,
        profileImageUrl: event.receiverProfileImageUrl,
      );

      // Start camera preview in parallel with the API call for video calls.
      if (event.callType == AppConstants.callTypeVideo) {
        unawaited(_callService.startLocalPreview());
      }

      // Emit with pending ID so the outgoing call screen is visible immediately.
      emit(CallInitiated(
        callId: 'pending',
        receiverId: event.receiverId,
        receiverName: _otherUserName,
        receiverRole: _otherUserRole,
        receiverProfileImageUrl: _otherUserProfileImageUrl,
        callType: event.callType,
        signalData: const {},
      ));

      // ── Step 2: API call (UI is already showing) ──
      final response = await _apiService.post(ApiEndpoints.callInitiate, {
        'callerId': user.uid,
        'receiverId': event.receiverId,
        'bookingId': event.bookingId,
        'callType': event.callType,
        'callerName': user.displayName ?? '',
        'callerRole': callerRole,
        'callerProfileImageUrl': user.photoURL,
      });

      if (response['success'] != true) {
        // API rejected — pop the already-visible call screen gracefully.
        emit(CallEnded(callId: 'pending', duration: 0, reason: 'initiation_failed'));
        emit(CallError(message: response['message']?.toString() ?? 'Failed to initiate call'));
        _resetCallSession();
        return;
      }

      // Guard: if the user cancelled the call while the API was in-flight
      // (EndCallRequested was processed concurrently), abort here.
      if (state is CallEnded || state is CallError || state is CallInitial) {
        _resetCallSession();
        return;
      }

      final call = response['call'] as Map<String, dynamic>;
      final signalData = (response['signalData'] is Map<String, dynamic>)
          ? response['signalData'] as Map<String, dynamic>
          : <String, dynamic>{};

      // Use names and images returned by Neo4j — correct even for phone-auth
      // users whose Firebase displayName / photoURL are null.
      final neo4jCallerName = call['callerName']?.toString() ?? '';
      final neo4jCallerImage = call['callerProfileImageUrl']?.toString();

      _currentCallId = call['id']?.toString() ?? '';
      _currentSignalData = signalData;
      // Prefer Neo4j name/image over the local values set above.
      _otherUserName = (call['receiverName']?.toString().isNotEmpty == true)
          ? call['receiverName']!.toString()
          : event.receiverName;
      _otherUserProfileImageUrl = (call['receiverProfileImageUrl'] as String?)?.isNotEmpty == true
          ? call['receiverProfileImageUrl'] as String?
          : event.receiverProfileImageUrl;

      // Update identity cache with server-confirmed values.
      CallIdentityResolver.preCacheIdentity(
        userId: event.receiverId,
        displayName: _otherUserName,
        role: _otherUserRole,
        profileImageUrl: _otherUserProfileImageUrl,
      );

      // ── Step 3: Re-emit with real call ID so state consumers can track it ──
      emit(CallInitiated(
        callId: _currentCallId ?? '',
        receiverId: event.receiverId,
        receiverName: _otherUserName,
        receiverRole: _otherUserRole,
        receiverProfileImageUrl: _otherUserProfileImageUrl,
        callType: event.callType,
        signalData: signalData,
      ));

      final callerImageForSignal = (neo4jCallerImage?.isNotEmpty == true)
          ? neo4jCallerImage
          : user.photoURL;

      await _socketService.send('call_request', {
        'callId': _currentCallId,
        'bookingId': event.bookingId,
        'receiverId': event.receiverId,
        'callType': event.callType,
        'callerName': neo4jCallerName.isNotEmpty ? neo4jCallerName : (user.displayName ?? ''),
        'callerRole': callerRole,
        'callerProfileImageUrl': callerImageForSignal,
        'signalData': signalData,
      });
    } catch (e) {
      // Network or unexpected error — pop the call screen if it was already shown.
      if (state is CallInitiated) {
        emit(CallEnded(callId: _currentCallId ?? 'pending', duration: 0, reason: 'initiation_failed'));
      }
      emit(CallError(message: 'Failed to initiate call: $e'));
      _resetCallSession();
    }
  }

  Future<void> _onAnswerCallRequested(
    AnswerCallRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      _currentCallId = event.callId;
      // Preserve _currentCallType (set by _onIncomingCallReceived) when signalData
      // has no callType — e.g. FCM-delivered calls where signalData is sparse.
      _currentCallType = event.signalData['callType']?.toString() ?? _currentCallType;
      _currentSignalData = event.signalData;
      _isLocalParticipantConnected = false;
      _pendingRemoteUid = null;

      final user = _auth.currentUser;
      if (user == null) {
        emit(const CallError(message: 'User not authenticated'));
        return;
      }

      // _otherUserId is normally set by _onIncomingCallReceived.
      // FCM-path calls may deliver AnswerCallRequested before IncomingCallReceived
      // fully processes — recover callerId from signalData so ICE candidates have
      // a valid targetUserId instead of sending to an empty room and silently failing.
      if (_otherUserId.isEmpty) {
        final fallbackCallerId = event.signalData['callerId']?.toString() ?? '';
        if (fallbackCallerId.isEmpty) {
          emit(const CallError(message: 'Cannot answer: caller identity unknown. Please try again.'));
          return;
        }
        _otherUserId = fallbackCallerId;
      }

      // Emit UI state immediately so receiver sees the call screen without delay.
      emit(CallConnecting(
        callId: event.callId,
        callType: _currentCallType,
        isCaller: false,
        otherUserName: _otherUserName,
        otherUserRole: _otherUserRole,
        otherUserProfileImageUrl: _otherUserProfileImageUrl,
      ));

      // Background: update status and cancel notification — don't block WebRTC setup.
      unawaited(Future<void>.microtask(() async {
        try {
          await _apiService.post(ApiEndpoints.callUpdateStatus, {
            'callId': event.callId,
            'status': 'answered',
            'userId': user.uid,
          });
          await NotificationService().cancelCallNotification(event.callId);
        } catch (_) {}
      }));

      // Peer connection must exist BEFORE call_accept — caller sends offer on receipt.
      await _callService.configureSession(
        callId: event.callId,
        peerUserId: _otherUserId,
        isCaller: false,
      );

      if (_currentCallType == AppConstants.callTypeVideo) {
        await _callService.joinVideoCall();
      } else {
        await _callService.joinVoiceCall();
      }

      await _socketService.send('call_accept', {
        'callId': event.callId,
        'targetUserId': _otherUserId,
      });
    } catch (e) {
      emit(CallError(message: 'Failed to answer call: $e'));
    }
  }

  Future<void> _onCallAnswerAcceptedByReceiver(
    CallAnswerAcceptedByReceiver event,
    Emitter<CallState> emit,
  ) async {
    // Guard: ignore duplicate call_accept events once we're already connecting/connected.
    if (state is CallConnecting || state is CallConnected) return;

    try {
      emit(CallConnecting(
        callId: event.callId,
        callType: event.callType,
        isCaller: true,
        otherUserName: _otherUserName,
        otherUserRole: _otherUserRole,
        otherUserProfileImageUrl: _otherUserProfileImageUrl,
      ));

      _isLocalParticipantConnected = false;
      _pendingRemoteUid = null;

      await _callService.configureSession(
        callId: event.callId,
        peerUserId: _otherUserId,
        isCaller: true,
      );

      if (event.callType == AppConstants.callTypeVideo) {
        await _callService.joinVideoCall();
      } else {
        await _callService.joinVoiceCall();
      }
    } catch (e) {
      emit(CallError(message: 'Failed to join accepted call: $e'));
    }
  }

  Future<void> _onEndCallRequested(
    EndCallRequested event,
    Emitter<CallState> emit,
  ) async {
    // Snapshot context BEFORE reset — cleanup runs fire-and-forget after.
    final otherUserId = _otherUserId;
    final bookingId = _currentBookingId;
    final callType = _currentCallType;
    final userId = _auth.currentUser?.uid;

    // Fire call_end to the remote user in PARALLEL with our own UI dismissal.
    // Don't await — even if the socket is slow, our UI shouldn't wait on it.
    if (otherUserId.isNotEmpty && event.callId.isNotEmpty && event.callId != 'pending') {
      unawaited(
        _socketService.send('call_end', {
          'callId': event.callId,
          'targetUserId': otherUserId,
          'duration': event.duration,
        }).catchError((_) {}),
      );
    }

    // Emit terminal state so the UI pops immediately.
    emit(CallEnded(callId: event.callId, duration: event.duration, reason: 'normal'));
    _resetCallSession();

    // Immediately cancel the WebRTC session so any in-flight socket events
    // (late ICE candidates, delayed offers from a restart, etc.) are ignored
    // before the async leaveChannel() runs.
    _callService.cancelSession();

    // Make sure the minimize floating bar dismisses with the call.
    CallMinimizeService.instance.restore();

    unawaited(_cleanupAfterEnd(event, otherUserId, bookingId, callType, userId));
  }

  Future<void> _cleanupAfterEnd(
    EndCallRequested event,
    String otherUserId,
    String? bookingId,
    String callType,
    String? userId,
  ) async {
    // call_end socket event was fired in _onEndCallRequested already.
    try {
      await _callService.leaveChannel();
    } catch (_) {}
    try {
      await NotificationService().cancelCallNotification(event.callId);
    } catch (_) {}

    final canUpdateBackend = event.callId.isNotEmpty && event.callId != 'pending';
    if (!canUpdateBackend) return;

    try {
      await _apiService.post(ApiEndpoints.callUpdateStatus, {
        'callId': event.callId,
        'status': 'ended',
        'duration': event.duration,
        if (userId != null) 'userId': userId,
      });
    } catch (_) {}

    // Log the call in the chat thread so both parties have a record.
    if (bookingId != null && bookingId.isNotEmpty && otherUserId.isNotEmpty) {
      final label = callType == AppConstants.callTypeVideo ? 'Video call' : 'Voice call';
      final summary = event.duration > 0
          ? '$label • ${_formatCallDuration(event.duration)}'
          : label;
      try {
        await _socketService.send('chat_send', {
          'receiverId': otherUserId,
          'bookingId': bookingId,
          'messageText': summary,
          'messageType': 'call',
          'clientMessageId': '${event.callId}_call_log',
        });
      } catch (_) {}
    }
  }

  String _formatCallDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }

  Future<void> _onRejectCallRequested(
    RejectCallRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      final otherUserId = _otherUserId;
      final bookingId = _currentBookingId;

      await NotificationService().cancelCallNotification(event.callId);

      await _apiService.post(ApiEndpoints.callUpdateStatus, {
        'callId': event.callId,
        'status': 'rejected',
        if (_auth.currentUser != null) 'userId': _auth.currentUser!.uid,
      });

      if (otherUserId.isNotEmpty) {
        await _socketService.send('call_reject', {
          'callId': event.callId,
          'targetUserId': otherUserId,
        });
      }

      emit(CallEnded(callId: event.callId, duration: 0, reason: 'rejected'));
      _resetCallSession();

      if (bookingId != null && bookingId.isNotEmpty && otherUserId.isNotEmpty) {
        try {
          await _socketService.send('chat_send', {
            'receiverId': otherUserId,
            'bookingId': bookingId,
            'messageText': 'Missed call',
            'messageType': 'call',
            'clientMessageId': '${event.callId}_call_log',
          });
        } catch (_) {}
      }
    } catch (e) {
      emit(CallError(message: 'Failed to reject call: $e'));
    }
  }

  Future<void> _onMissedCallReported(
    MissedCallReported event,
    Emitter<CallState> emit,
  ) async {
    try {
      final otherUserId = _otherUserId;
      final bookingId = _currentBookingId;

      await _apiService.post(ApiEndpoints.callUpdateStatus, {
        'callId': event.callId,
        'status': 'missed',
        if (_auth.currentUser != null) 'userId': _auth.currentUser!.uid,
      });

      emit(CallEnded(callId: event.callId, duration: 0, reason: 'missed'));
      _resetCallSession();

      if (bookingId != null && bookingId.isNotEmpty && otherUserId.isNotEmpty) {
        try {
          await _socketService.send('chat_send', {
            'receiverId': otherUserId,
            'bookingId': bookingId,
            'messageText': 'Missed call',
            'messageType': 'call',
            'clientMessageId': '${event.callId}_call_log',
          });
        } catch (_) {}
      }
    } catch (e) {
      emit(CallError(message: 'Failed to report missed call: $e'));
    }
  }

  Future<void> _onToggleMuteRequested(
    ToggleMuteRequested event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallConnected) {
      final currentState = state as CallConnected;
      final newMuteState = !currentState.isMuted;
      await _callService.muteLocalAudio(newMuteState);
      emit(currentState.copyWith(isMuted: newMuteState));
    } else if (state is CallConnecting) {
      final cs = state as CallConnecting;
      final newMuteState = !cs.isMuted;
      await _callService.muteLocalAudio(newMuteState);
      emit(cs.copyWith(isMuted: newMuteState));
    }
  }

  Future<void> _onToggleSpeakerRequested(
    ToggleSpeakerRequested event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallConnected) {
      final currentState = state as CallConnected;
      final newSpeakerState = !currentState.isSpeakerOn;
      await _callService.enableSpeakerphone(newSpeakerState);
      emit(currentState.copyWith(isSpeakerOn: newSpeakerState));
    }
  }

  Future<void> _onToggleVideoRequested(
    ToggleVideoRequested event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallConnected) {
      final currentState = state as CallConnected;
      final newVideoState = !currentState.isVideoOn;
      await _callService.muteLocalVideo(!newVideoState);
      emit(currentState.copyWith(isVideoOn: newVideoState));
    } else if (state is CallConnecting) {
      final cs = state as CallConnecting;
      final newVideoState = !cs.isVideoOn;
      await _callService.muteLocalVideo(!newVideoState);
      emit(cs.copyWith(isVideoOn: newVideoState));
    }
  }

  Future<void> _onSwitchCameraRequested(
    SwitchCameraRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      await _callService.switchCamera();
    } catch (e) {
      emit(CallError(message: 'Failed to switch camera: $e'));
    }
  }

  Future<void> _onCallStateChanged(
    CallStateChanged event,
    Emitter<CallState> emit,
  ) async {
    if (event.state == CallConnectionState.connected) {
      _isLocalParticipantConnected = true;
      _emitConnectedIfReady(emit);
      return;
    }

    if (event.state == CallConnectionState.error) {
      if (state is CallConnected) {
        // ICE restart timed out after a connected call lost its connection.
        // End the call gracefully rather than leaving the UI stuck.
        final connected = state as CallConnected;
        final callIdSnapshot = _currentCallId ?? connected.callId;
        final otherUserIdSnapshot = _otherUserId;
        final duration = _callStartTime != null
            ? DateTime.now().difference(_callStartTime!).inSeconds
            : 0;
        emit(CallEnded(callId: callIdSnapshot, duration: duration, reason: 'connection_lost'));
        _resetCallSession();
        _callService.cancelSession();
        unawaited(() async {
          if (otherUserIdSnapshot.isNotEmpty && callIdSnapshot.isNotEmpty) {
            try {
              await _socketService.send('call_end', {
                'callId': callIdSnapshot,
                'targetUserId': otherUserIdSnapshot,
                'duration': duration,
              });
            } catch (_) {}
          }
          try { await _callService.leaveChannel(); } catch (_) {}
        }());
      } else if (state is! CallEnded) {
        // Connecting-phase failure — notify the other participant so their
        // screen doesn't hang indefinitely.
        final callIdSnapshot = _currentCallId;
        final otherUserIdSnapshot = _otherUserId;
        if (callIdSnapshot != null && callIdSnapshot.isNotEmpty && otherUserIdSnapshot.isNotEmpty) {
          _resetCallSession();
          _callService.cancelSession();
          unawaited(() async {
            try { await _callService.leaveChannel(); } catch (_) {}
            try {
              await _socketService.send('call_end', {
                'callId': callIdSnapshot,
                'targetUserId': otherUserIdSnapshot,
                'duration': 0,
              });
            } catch (_) {}
          }());
        }
        emit(const CallError(message: 'Call connection failed. Please try again.'));
      }
      return;
    }

    if (event.state == CallConnectionState.disconnected) {
      _isLocalParticipantConnected = false;
      // RTCPeerConnectionStateDisconnected is transient — WebRTC may recover
      // via ICE restart.  Do NOT auto-end here; call lifecycle is managed only
      // by explicit EndCallRequested or a remote call_end socket event.
    }
  }

  Future<void> _onRemoteUserJoined(
    RemoteUserJoined event,
    Emitter<CallState> emit,
  ) async {
    _pendingRemoteUid = event.uid;
    if (state is CallConnected) {
      final currentState = state as CallConnected;
      emit(currentState.copyWith(remoteUid: event.uid));
    } else if (state is CallConnecting) {
      _emitConnectedIfReady(emit);
    }
  }

  Future<void> _onRemoteUserLeft(
    RemoteUserLeft event,
    Emitter<CallState> emit,
  ) async {
    _pendingRemoteUid = null;
    if (state is CallConnected) {
      final currentState = state as CallConnected;
      emit(currentState.copyWith(remoteUid: null));
    }
  }

  Future<void> _onIncomingCallReceived(
    IncomingCallReceived event,
    Emitter<CallState> emit,
  ) async {
    await NotificationService().cancelCallNotification(event.callId);

    _currentCallId = event.callId;
    _currentBookingId = event.bookingId.isNotEmpty ? event.bookingId : null;
    _currentCallType = event.callType;
    _otherUserId = event.callerId;
    _otherUserName = event.callerName;
    _otherUserRole = event.callerRole;
    // Prefer a non-null URL: the REST-initiated event carries the Neo4j
    // profile image; a redundant socket event may arrive with null.
    _otherUserProfileImageUrl =
        event.callerProfileImageUrl ?? _otherUserProfileImageUrl;
    _currentSignalData = event.signalData;

    // Pre-cache the caller's identity so IncomingCallScreen renders the avatar
    // instantly without an API round-trip.
    CallIdentityResolver.preCacheIdentity(
      userId: event.callerId,
      displayName: event.callerName,
      role: event.callerRole,
      profileImageUrl: _otherUserProfileImageUrl,
    );

    emit(CallRinging(
      callId: event.callId,
      callerId: event.callerId,
      callerName: event.callerName,
      callerRole: event.callerRole,
      callerProfileImageUrl: event.callerProfileImageUrl,
      callType: event.callType,
      signalData: event.signalData,
    ));
  }

  Future<void> _onRemoteCallStatusUpdated(
    RemoteCallStatusUpdated event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallEnded || state is CallError) return;

    final reason = event.status == AppConstants.callStatusRejected
        ? 'rejected'
        : 'ended';

    // Emit terminal state FIRST so the UI pops immediately (same pattern as
    // _onEndCallRequested), then clean up async so the pop is never blocked.
    emit(CallEnded(callId: event.callId, duration: event.duration, reason: reason));
    _resetCallSession();
    _callService.cancelSession();
    // Make sure the minimize floating bar dismisses with the call.
    CallMinimizeService.instance.restore();
    unawaited(_callService.leaveChannel());
  }

  Future<void> _onLoadCallHistoryRequested(
    LoadCallHistoryRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      final response = await _apiService.get(ApiEndpoints.callHistory(event.userId));

      if (response['success'] == true) {
        final calls = (response['calls'] as List)
            .map((call) => CallHistoryItem.fromJson(call))
            .toList();

        emit(CallHistoryLoaded(history: calls));
      } else {
        emit(const CallError(message: 'Failed to load call history'));
      }
    } catch (e) {
      emit(CallError(message: 'Failed to load call history: $e'));
    }
  }

  void _resetCallSession() {
    _currentCallId = null;
    _currentBookingId = null;
    _callStartTime = null;
    _otherUserId = '';
    _otherUserName = '';
    _otherUserRole = AppConstants.roleUser;
    _otherUserProfileImageUrl = null;
    _currentCallType = AppConstants.callTypeVoice;
    _pendingRemoteUid = null;
    _currentSignalData = null;
    _isLocalParticipantConnected = false;
  }

  @override
  Future<void> close() async {
    await _callStateSubscription?.cancel();
    await _remoteUserSubscription?.cancel();
    await _socketSubscription?.cancel();
    await _notificationSubscription?.cancel();
    await _callService.dispose();
    return super.close();
  }
}
