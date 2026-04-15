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
  
  DateTime? _callStartTime;
  String? _currentCallId;
  String _otherUserName = '';
  String _otherUserRole = AppConstants.roleUser;
  String? _otherUserProfileImageUrl;
  String _currentCallType = AppConstants.callTypeVoice;
  int? _pendingRemoteUid; // Stores remote uid if they join before CallConnected

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
    if (appId.isNotEmpty && appId != 'your_agora_app_id') {
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
      });

      if (response['success'] == true) {
        final call = response['call'];
        final agoraConfig = response['agoraConfig'];

        _currentCallId = call['id'];
        _currentCallType = event.callType;
        _otherUserName = event.receiverName;
        _otherUserRole = event.receiverRole;
        _otherUserProfileImageUrl = event.receiverProfileImageUrl;

        emit(CallInitiated(
          callId: call['id'],
          receiverId: event.receiverId,
          receiverName: event.receiverName,
          receiverRole: event.receiverRole,
          receiverProfileImageUrl: event.receiverProfileImageUrl,
          callType: event.callType,
          agoraConfig: agoraConfig,
        ));

        emit(CallConnecting(
          callId: call['id'],
          callType: event.callType,
          isCaller: true,
          otherUserName: _otherUserName,
          otherUserRole: _otherUserRole,
          otherUserProfileImageUrl: _otherUserProfileImageUrl,
        ));

        final channel = agoraConfig['channel']?.toString() ?? '';
        if (channel.isEmpty) {
          emit(const CallError(message: 'Missing call channel configuration'));
          return;
        }

        final uid = _parseAgoraUid(agoraConfig['uid'], user.uid);
        final resolvedAppId = _resolveAgoraAppId(agoraConfig['appId']);
        final token = agoraConfig['token'];
        
        print('[CallBloc] DIAGNOSE_JOIN_INITIATE: '
            'channel=$channel, uid=$uid, appId=$resolvedAppId, '
            'token_length=${token?.toString().length ?? 0}, token_null=${token == null}');

        // Initialize Agora engine with app ID
        await _agoraService.initialize(resolvedAppId);

        // Join Agora channel
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

      // Initialize Agora engine with app ID
      final appId = event.agoraConfig['appId'];
      if (appId != null || AgoraConfig.isConfigured) {
        await _agoraService.initialize(_resolveAgoraAppId(appId));
      }

      final channel = event.agoraConfig['channel']?.toString() ?? '';
      if (channel.isEmpty) {
        emit(const CallError(message: 'Missing call channel configuration'));
        return;
      }

      final uid = _parseAgoraUid(event.agoraConfig['uid'], user.uid);
      final resolvedAppId = _resolveAgoraAppId(event.agoraConfig['appId']);
      final token = event.agoraConfig['token'];
      
      print('[CallBloc] DIAGNOSE_JOIN_ANSWER: '
          'channel=$channel, uid=$uid, appId=$resolvedAppId, '
          'token_length=${token?.toString().length ?? 0}, token_null=${token == null}');

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
      _currentCallType = AppConstants.callTypeVoice;
      _pendingRemoteUid = null;
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
      _pendingRemoteUid = null;
      return;
    }

    if (event.state == CallConnectionState.error) {
      if (state is! CallConnected) {
        emit(const CallError(message: 'Call connection timed out. Please try again.'));
      }
      return;
    } else if (event.state == CallConnectionState.disconnected) {
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
        _currentCallType = AppConstants.callTypeVoice;
      }
    }
  }

  Future<void> _onRemoteUserJoined(
    RemoteUserJoined event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallConnected) {
      final currentState = state as CallConnected;
      emit(currentState.copyWith(remoteUid: event.uid));
    } else if (state is CallConnecting) {
      // Remote user joined before we transitioned to CallConnected — store for later
      _pendingRemoteUid = event.uid;
    }
  }

  Future<void> _onRemoteUserLeft(
    RemoteUserLeft event,
    Emitter<CallState> emit,
  ) async {
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
    return super.close();
  }
}
