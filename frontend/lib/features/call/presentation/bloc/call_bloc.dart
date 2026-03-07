import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'call_event.dart';
import 'call_state.dart';
import '../../../../core/services/agora_call_service.dart' as agora;
import '../../../../core/services/api_service.dart';
import '../../../../core/services/notification_service.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  final agora.AgoraCallService _agoraService;
  final ApiService _apiService;
  final FirebaseAuth _auth;

  StreamSubscription? _callStateSubscription;
  StreamSubscription? _remoteUserSubscription;
  
  DateTime? _callStartTime;
  String? _currentCallId;
  String _otherUserName = '';
  String _otherUserRole = 'user';
  String? _otherUserProfileImageUrl;
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

      // Get FCM token for push notification
      final fcmToken = await NotificationService().getToken();

      // Call backend to initiate call
      final response = await _apiService.post('/api/calls/initiate', {
        'callerId': user.uid,
        'receiverId': event.receiverId,
        'bookingId': event.bookingId,
        'callType': event.callType,
        'receiverFcmToken': fcmToken,
        'callerName': user.displayName ?? 'User',
        'callerRole': event.receiverRole == 'provider' ? 'seeker' : 'provider',
      });

      if (response['success'] == true) {
        final call = response['call'];
        final agoraConfig = response['agoraConfig'];

        _currentCallId = call['id'];
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

        // Initialize Agora engine with app ID
        await _agoraService.initialize(agoraConfig['appId']);

        // Join Agora channel
        if (event.callType == 'voice') {
          await _agoraService.joinVoiceCall(
            channel: agoraConfig['channel'],
            uid: agoraConfig['uid'],
            token: agoraConfig['token'],
          );
        } else {
          await _agoraService.joinVideoCall(
            channel: agoraConfig['channel'],
            uid: agoraConfig['uid'],
            token: agoraConfig['token'],
          );
        }

        emit(CallConnecting(
          callId: call['id'],
          callType: event.callType,
          isCaller: true,
          otherUserName: _otherUserName,
          otherUserRole: _otherUserRole,
          otherUserProfileImageUrl: _otherUserProfileImageUrl,
        ));
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

      // Update call status to answered
      await _apiService.post('/api/calls/update-status', {
        'callId': event.callId,
        'status': 'answered',
      });

      // Initialize Agora engine with app ID
      final appId = event.agoraConfig['appId'];
      if (appId != null) {
        await _agoraService.initialize(appId);
      }

      // Join Agora channel
      final callType = event.agoraConfig['callType'] ?? 'voice';
      if (callType == 'voice') {
        await _agoraService.joinVoiceCall(
          channel: event.agoraConfig['channel'],
          uid: event.agoraConfig['uid'],
          token: event.agoraConfig['token'],
        );
      } else {
        await _agoraService.joinVideoCall(
          channel: event.agoraConfig['channel'],
          uid: event.agoraConfig['uid'],
          token: event.agoraConfig['token'],
        );
      }

      emit(CallConnecting(
        callId: event.callId,
        callType: callType,
        isCaller: false,
        otherUserName: _otherUserName,
        otherUserRole: _otherUserRole,
        otherUserProfileImageUrl: _otherUserProfileImageUrl,
      ));
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
      await _agoraService.leaveChannel();

      // Cancel call notification
      await NotificationService().cancelCallNotification(event.callId);

      // Update call status
      await _apiService.post('/api/calls/update-status', {
        'callId': event.callId,
        'status': 'ended',
        'duration': event.duration,
      });

      emit(CallEnded(
        callId: event.callId,
        duration: event.duration,
        reason: 'normal',
      ));

      _currentCallId = null;
      _callStartTime = null;
      _otherUserName = '';
      _otherUserRole = 'user';
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
      
      await _apiService.post('/api/calls/update-status', {
        'callId': event.callId,
        'status': 'rejected',
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
      await _apiService.post('/api/calls/update-status', {
        'callId': event.callId,
        'status': 'missed',
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
    if (event.state == CallConnectionState.connected && state is CallConnecting) {
      final connectingState = state as CallConnecting;
      _callStartTime = DateTime.now();
      
      emit(CallConnected(
        callId: connectingState.callId,
        callType: connectingState.callType,
        connectedAt: _callStartTime!,
        otherUserName: connectingState.otherUserName,
        otherUserRole: connectingState.otherUserRole,
        otherUserProfileImageUrl: connectingState.otherUserProfileImageUrl,
        remoteUid: _pendingRemoteUid,
      ));
      _pendingRemoteUid = null;
    } else if (event.state == CallConnectionState.disconnected) {
      if (_currentCallId != null && _callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!).inSeconds;
        
        // Update backend
        await _apiService.post('/api/calls/update-status', {
          'callId': _currentCallId,
          'status': 'ended',
          'duration': duration,
        });

        emit(CallEnded(
          callId: _currentCallId!,
          duration: duration,
          reason: 'normal',
        ));

        _currentCallId = null;
        _callStartTime = null;
        _otherUserName = '';
        _otherUserRole = 'user';
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

  @override
  Future<void> close() {
    _callStateSubscription?.cancel();
    _remoteUserSubscription?.cancel();
    return super.close();
  }
}
