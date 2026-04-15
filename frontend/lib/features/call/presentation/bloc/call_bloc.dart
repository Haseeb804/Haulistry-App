import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'call_event.dart';
import 'call_state.dart';
import '../../../../core/services/agora_call_service.dart' as agora;
import '../../../../core/services/api_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/agora_config.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  final agora.AgoraCallService _agoraService;
  final ApiService _apiService;
  final FirebaseAuth _auth;

  StreamSubscription? _callStateSubscription;
  StreamSubscription? _remoteUserSubscription;
  StreamSubscription? _tokenExpirySubscription;
  StreamSubscription? _notificationSubscription;
  
  DateTime? _callStartTime;
  String? _currentCallId;
  String _otherUserName = '';
  String _otherUserRole = AppConstants.roleUser;
  String? _otherUserProfileImageUrl;
  String _currentCallType = AppConstants.callTypeVoice;
  int? _pendingRemoteUid; // Stores remote uid if they join before CallConnected
  Map<String, dynamic>? _currentAgoraConfig; // Store current call's Agora config
  bool _isLocalParticipantConnected = false;

  CallBloc({
    agora.AgoraCallService? agoraService,
    ApiService? apiService,
    FirebaseAuth? auth,
  })  : _agoraService = agoraService ?? agora.AgoraCallService(),
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

    _setupCallStateListener();
    _setupNotificationListener();
  }

  void _setupCallStateListener() {
    _callStateSubscription = _agoraService.callStateStream.listen((callState) {
      add(CallStateChanged(_mapAgoraState(callState)));
    });

    _remoteUserSubscription = _agoraService.remoteUserStream.listen((remoteUser) {
      if (remoteUser.isJoined) {
        add(RemoteUserJoined(remoteUser.uid));
      } else {
        add(RemoteUserLeft(remoteUser.uid));
      }
    });

    _tokenExpirySubscription = _agoraService.tokenExpiryStream.listen((_) {
      unawaited(_refreshAgoraToken());
    });
  }

  void _setupNotificationListener() {
    _notificationSubscription = NotificationService().notificationStream.listen((data) {
      final type = data['type']?.toString();
      if (type != 'call_status') return;

      final callId = data['callId']?.toString() ?? '';
      if (callId.isEmpty || callId != _currentCallId) return;

      final status = data['status']?.toString().toLowerCase() ?? '';

      final otherName = data['otherUserName']?.toString();
      final otherRole = data['otherUserRole']?.toString();
      final otherProfileImage = data['otherUserProfileImageUrl']?.toString();
      if (otherName != null && otherName.isNotEmpty) {
        _otherUserName = otherName;
      }
      if (otherRole != null && otherRole.isNotEmpty) {
        _otherUserRole = otherRole;
      }
      if (otherProfileImage != null && otherProfileImage.isNotEmpty) {
        _otherUserProfileImageUrl = otherProfileImage;
      }

      if (status == 'answered' && state is CallInitiated) {
        add(CallAnswerAcceptedByReceiver(
          callId: callId,
          callType: data['callType']?.toString() ?? _currentCallType,
          agoraConfig: _currentAgoraConfig ?? const <String, dynamic>{},
        ));
        return;
      }

      if (status == AppConstants.callStatusRejected ||
          status == AppConstants.callStatusMissed ||
          status == AppConstants.callStatusEnded) {
        if (state is CallEnded || state is CallError) return;
        final duration = int.tryParse(data['duration']?.toString() ?? '0') ?? 0;
        add(EndCallRequested(callId: callId, duration: duration));
      }
    });
  }

  void _emitConnectedIfReady(Emitter<CallState> emit) {
    if (!_isLocalParticipantConnected || _pendingRemoteUid == null) {
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

    if (state is CallConnecting) {
      final connectingState = state as CallConnecting;
      callId = connectingState.callId;
      callType = connectingState.callType;
      otherUserName = connectingState.otherUserName;
      otherUserRole = connectingState.otherUserRole;
      otherUserProfileImageUrl = connectingState.otherUserProfileImageUrl;
    } else if (state is CallInitiated) {
      final initiatedState = state as CallInitiated;
      callId = initiatedState.callId;
      callType = initiatedState.callType;
      otherUserName = initiatedState.receiverName;
      otherUserRole = initiatedState.receiverRole;
      otherUserProfileImageUrl = initiatedState.receiverProfileImageUrl;
    }

    if (callId.isEmpty) {
      emit(const CallError(message: 'Unable to resolve active call while connecting'));
      return;
    }

    _callStartTime ??= DateTime.now();

    emit(CallConnected(
      callId: callId,
      callType: callType,
      connectedAt: _callStartTime!,
      otherUserName: otherUserName,
      otherUserRole: otherUserRole,
      otherUserProfileImageUrl: otherUserProfileImageUrl,
      remoteUid: _pendingRemoteUid,
    ));
  }

  CallConnectionState _mapAgoraState(agora.CallState agoraState) {
    switch (agoraState) {
      case agora.CallState.connecting:
        return CallConnectionState.connecting;
      case agora.CallState.connected:
        return CallConnectionState.connected;
      case agora.CallState.disconnected:
        return CallConnectionState.disconnected;
      case agora.CallState.error:
        return CallConnectionState.error;
      default:
        return CallConnectionState.idle;
    }
  }

  int _deriveFallbackUid(String userId) {
    final hash = userId.hashCode & 0x7fffffff;
    return (hash % 99999) + 1;
  }

  int _parseAgoraUid(dynamic rawUid, String fallbackUserId) {
    if (rawUid is int && rawUid > 0) return rawUid;
    final parsed = int.tryParse(rawUid?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;
    return _deriveFallbackUid(fallbackUserId);
  }

  String _resolveAgoraAppId(dynamic rawAppId) {
    final appId = rawAppId?.toString().trim() ?? '';
    final normalized = appId.toLowerCase();
    final looksPlaceholder =
        normalized.isEmpty ||
        normalized == 'your_agora_app_id' ||
        normalized.startsWith('your_agora_app_id') ||
        normalized == 'your_app_id' ||
        normalized == 'placeholder';
    if (!looksPlaceholder) {
      return appId;
    }
    return AgoraConfig.appId;
  }

  Future<void> _onInitiateCallRequested(
    InitiateCallRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      emit(const CallLoading());

      final user = _auth.currentUser;
      if (user == null) {
        emit(const CallError(message: 'User not authenticated'));
        return;
      }

      // Call backend to initiate call
      final response = await _apiService.post(ApiEndpoints.callInitiate, {
        'callerId': user.uid,
        'receiverId': event.receiverId,
        'bookingId': event.bookingId,
        'callType': event.callType,
        'callerName': user.displayName ?? 'User',
        'callerRole': event.receiverRole == AppConstants.roleProvider
            ? AppConstants.roleSeeker
            : AppConstants.roleProvider,
        'callerProfileImageUrl': user.photoURL, // Caller's profile image for notification
      });

      if (response['success'] == true) {
        final call = response['call'];
        final agoraConfig = response['agoraConfig'] as Map<String, dynamic>;
        


        _currentCallId = call['id'];
        _currentCallType = event.callType;
        _otherUserName = (call['receiverName'] as String?)?.trim().isNotEmpty == true
          ? call['receiverName'] as String
          : event.receiverName;
        _otherUserRole = (call['receiverRole'] as String?)?.trim().isNotEmpty == true
          ? call['receiverRole'] as String
          : event.receiverRole;
        _otherUserProfileImageUrl =
          (call['receiverProfileImageUrl'] as String?)?.isNotEmpty == true
            ? call['receiverProfileImageUrl'] as String
            : event.receiverProfileImageUrl;
        _currentAgoraConfig = agoraConfig; // Store for later use when receiver accepts
        _isLocalParticipantConnected = false;
        _pendingRemoteUid = null;

        emit(CallInitiated(
          callId: call['id'],
          receiverId: event.receiverId,
          receiverName: _otherUserName,
          receiverRole: _otherUserRole,
          receiverProfileImageUrl: _otherUserProfileImageUrl,
          callType: event.callType,
          agoraConfig: agoraConfig,
        ));

        // IMPORTANT: Do NOT emit CallConnecting or join Agora yet.
        // The caller will join ONLY after the receiver accepts.
        // The outgoing_call_screen will show ringing UI and poll backend status.
        // When status='answered', it will emit CallAnswerAcceptedByReceiver event.

        // Pre-initialize Agora engine (but don't join yet)
        final resolvedAppId = _resolveAgoraAppId(agoraConfig['appId']);
        await _agoraService.initialize(resolvedAppId);
        
      } else {
        emit(CallError(message: response['message'] ?? 'Failed to initiate call'));
      }
    } catch (e) {
      emit(CallError(message: 'Failed to initiate call: $e'));
    }
  }

  Future<void> _onAnswerCallRequested(
    AnswerCallRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      _currentCallId = event.callId;
      _currentCallType = event.agoraConfig['callType'] ?? AppConstants.callTypeVoice;
      _currentAgoraConfig = event.agoraConfig;
      _isLocalParticipantConnected = false;
      _pendingRemoteUid = null;

      final user = _auth.currentUser;
      if (user == null) {
        emit(const CallError(message: 'User not authenticated'));
        return;
      }

      // Update call status to answered
      await _apiService.post(ApiEndpoints.callUpdateStatus, {
        'callId': event.callId,
        'status': 'answered',
        'userId': user.uid,
      });

      // Stop ringing immediately once accepted.
      await NotificationService().cancelCallNotification(event.callId);

      // Transition incoming -> accepted/connecting before Agora join finishes.
      final callType = event.agoraConfig['callType'] ?? AppConstants.callTypeVoice;
      emit(CallConnecting(
        callId: event.callId,
        callType: callType,
        isCaller: false,
        otherUserName: _otherUserName,
        otherUserRole: _otherUserRole,
        otherUserProfileImageUrl: _otherUserProfileImageUrl,
      ));

      // Ensure Agora is initialized before joining
      try {
        final appId = event.agoraConfig['appId'];
        final resolvedAppId = _resolveAgoraAppId(appId);
        if (resolvedAppId.isNotEmpty) {
          await _agoraService.initialize(resolvedAppId);
        }
      } catch (e) {
        emit(CallError(message: 'Failed to initialize Agora engine: $e'));
        return;
      }

      final channel = event.agoraConfig['channel']?.toString() ?? '';
      if (channel.isEmpty) {
        emit(const CallError(message: 'Missing call channel configuration'));
        return;
      }

      final uid = _parseAgoraUid(event.agoraConfig['uid'], user.uid);
      final token = event.agoraConfig['token']?.toString();

      // Join Agora channel
      if (callType == 'voice') {
        await _agoraService.joinVoiceCall(
          channel: channel,
          uid: uid,
          token: token,
        );
      } else {
        await _agoraService.joinVideoCall(
          channel: channel,
          uid: uid,
          token: token,
        );
      }
    } catch (e) {
      emit(CallError(message: 'Failed to answer call: $e'));
    }
  }

  Future<void> _onCallAnswerAcceptedByReceiver(
    CallAnswerAcceptedByReceiver event,
    Emitter<CallState> emit,
  ) async {
    try {
      // The receiver has accepted the call, now the caller joins
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

      // Use stored config if event config is empty
      final config = event.agoraConfig.isNotEmpty ? event.agoraConfig : (_currentAgoraConfig ?? {});
      
      if (config.isEmpty) {
        emit(const CallError(message: 'Missing Agora configuration for the receiver accepted call'));
        return;
      }

      final channel = config['channel']?.toString() ?? '';
      if (channel.isEmpty) {
        emit(const CallError(message: 'Missing call channel configuration'));
        return;
      }

      // Ensure Agora is initialized before joining
      try {
        final appId = config['appId']?.toString() ?? '';
        if (appId.isNotEmpty) {
          await _agoraService.initialize(_resolveAgoraAppId(appId));
        }
      } catch (e) {
        emit(CallError(message: 'Failed to initialize Agora engine: $e'));
        return;
      }

      final uid = _parseAgoraUid(config['uid'], _auth.currentUser?.uid ?? 'unknown');
      final token = config['token']?.toString();

      // Join Agora channel now that receiver accepted
      if (event.callType == 'voice') {
        await _agoraService.joinVoiceCall(
          channel: channel,
          uid: uid,
          token: token,
        );
      } else {
        await _agoraService.joinVideoCall(
          channel: channel,
          uid: uid,
          token: token,
        );
      }
    } catch (e) {
      emit(CallError(message: 'Failed to join accepted call: $e'));
    }
  }

  Future<void> _onEndCallRequested(
    EndCallRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      // Leave Agora channel
      try {
        await _agoraService.leaveChannel();
      } catch (_) {
        // Continue local teardown even if engine/channel already gone.
      }

      // Cancel call notification
      await NotificationService().cancelCallNotification(event.callId);

      // Update call status when we have a valid persisted call id.
      final canUpdateBackend = event.callId.isNotEmpty && event.callId != 'pending';
      final user = _auth.currentUser;
      if (canUpdateBackend) {
        await _apiService.post(ApiEndpoints.callUpdateStatus, {
          'callId': event.callId,
          'status': 'ended',
          'duration': event.duration,
          if (user != null) 'userId': user.uid,
        });
      }

      emit(CallEnded(
        callId: event.callId,
        duration: event.duration,
        reason: 'normal',
      ));

      _currentCallId = null;
      _callStartTime = null;
      _otherUserName = '';
      _otherUserRole = AppConstants.roleUser;
      _otherUserProfileImageUrl = null;
      _currentCallType = AppConstants.callTypeVoice;
      _pendingRemoteUid = null;
      _currentAgoraConfig = null;
      _isLocalParticipantConnected = false;
    } catch (e) {
      emit(CallError(message: 'Failed to end call: $e'));
    }
  }

  Future<void> _onRejectCallRequested(
    RejectCallRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      // Cancel call notification
      await NotificationService().cancelCallNotification(event.callId);
      
      await _apiService.post(ApiEndpoints.callUpdateStatus, {
        'callId': event.callId,
        'status': 'rejected',
        if (_auth.currentUser != null) 'userId': _auth.currentUser!.uid,
      });

      emit(CallEnded(
        callId: event.callId,
        duration: 0,
        reason: 'rejected',
      ));
      _currentCallId = null;
      _callStartTime = null;
      _otherUserName = '';
      _otherUserRole = AppConstants.roleUser;
      _otherUserProfileImageUrl = null;
      _currentCallType = AppConstants.callTypeVoice;
      _pendingRemoteUid = null;
      _currentAgoraConfig = null;
      _isLocalParticipantConnected = false;
    } catch (e) {
      emit(CallError(message: 'Failed to reject call: $e'));
    }
  }

  Future<void> _onMissedCallReported(
    MissedCallReported event,
    Emitter<CallState> emit,
  ) async {
    try {
      await _apiService.post(ApiEndpoints.callUpdateStatus, {
        'callId': event.callId,
        'status': 'missed',
        if (_auth.currentUser != null) 'userId': _auth.currentUser!.uid,
      });

      emit(CallEnded(
        callId: event.callId,
        duration: 0,
        reason: 'missed',
      ));
      _currentCallId = null;
      _callStartTime = null;
      _otherUserName = '';
      _otherUserRole = AppConstants.roleUser;
      _otherUserProfileImageUrl = null;
      _currentCallType = AppConstants.callTypeVoice;
      _pendingRemoteUid = null;
      _currentAgoraConfig = null;
      _isLocalParticipantConnected = false;
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
      
      await _agoraService.muteLocalAudio(newMuteState);
      
      emit(currentState.copyWith(isMuted: newMuteState));
    }
  }

  Future<void> _onToggleSpeakerRequested(
    ToggleSpeakerRequested event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallConnected) {
      final currentState = state as CallConnected;
      final newSpeakerState = !currentState.isSpeakerOn;
      
      await _agoraService.enableSpeakerphone(newSpeakerState);
      
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
      
      await _agoraService.muteLocalVideo(!newVideoState);
      
      emit(currentState.copyWith(isVideoOn: newVideoState));
    }
  }

  Future<void> _onSwitchCameraRequested(
    SwitchCameraRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      await _agoraService.switchCamera();
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
      if (state is! CallConnected) {
        emit(const CallError(message: 'Call connection failed. Please try again.'));
      }
      return;
    } else if (event.state == CallConnectionState.disconnected) {
      _isLocalParticipantConnected = false;
      if (_currentCallId != null && _callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!).inSeconds;
        
        // Update backend
        await _apiService.post(ApiEndpoints.callUpdateStatus, {
          'callId': _currentCallId,
          'status': 'ended',
          'duration': duration,
          if (_auth.currentUser != null) 'userId': _auth.currentUser!.uid,
        });

        emit(CallEnded(
          callId: _currentCallId!,
          duration: duration,
          reason: 'normal',
        ));

        _currentCallId = null;
        _callStartTime = null;
        _otherUserName = '';
        _otherUserRole = AppConstants.roleUser;
        _otherUserProfileImageUrl = null;
        _currentCallType = AppConstants.callTypeVoice;
        _pendingRemoteUid = null;
        _currentAgoraConfig = null;
      }
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
    // Cancel any existing call notification
    await NotificationService().cancelCallNotification(event.callId);
    
    // Store other user info for state transitions
    _otherUserName = event.callerName;
    _otherUserRole = event.callerRole;
    _otherUserProfileImageUrl = event.callerProfileImageUrl;
    
    emit(CallRinging(
      callId: event.callId,
      callerId: event.callerId,
      callerName: event.callerName,
      callerRole: event.callerRole,
      callerProfileImageUrl: event.callerProfileImageUrl,
      callType: event.callType,
      agoraConfig: event.agoraConfig,
    ));
  }

  Future<void> _onLoadCallHistoryRequested(
    LoadCallHistoryRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      final response = await _apiService.get('/calls/history/${event.userId}');

      if (response['success'] == true) {
        final calls = (response['calls'] as List)
            .map((call) => CallHistoryItem.fromJson(call))
            .toList();

        emit(CallHistoryLoaded(history: calls));
      } else {
        emit(CallError(message: 'Failed to load call history'));
      }
    } catch (e) {
      emit(CallError(message: 'Failed to load call history: $e'));
    }
  }

  Future<void> _refreshAgoraToken() async {
    try {
      final user = _auth.currentUser;
      final callId = _currentCallId;
      if (user == null || callId == null || callId.isEmpty) {
        return;
      }

      final response = await _apiService.post(ApiEndpoints.callRefreshToken, {
        'callId': callId,
        'userId': user.uid,
      });

      if (response['success'] != true) return;
      final agoraConfig = response['agoraConfig'] as Map<String, dynamic>?;
      final token = agoraConfig?['token']?.toString();
      if (token == null || token.isEmpty) return;

      await _agoraService.renewToken(token);
    } catch (_) {
      // Best effort; call can continue in app-certificate-disabled mode.
    }
  }

  @override
  Future<void> close() {
    _callStateSubscription?.cancel();
    _remoteUserSubscription?.cancel();
    _tokenExpirySubscription?.cancel();
    _notificationSubscription?.cancel();
    return super.close();
  }
}
