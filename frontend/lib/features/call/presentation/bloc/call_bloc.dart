import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/realtime_socket_service.dart';
import '../../../../core/services/webrtc_call_service.dart';
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
        ));
      }

      if (type == 'call_accept') {
        final callId = data['callId']?.toString() ?? '';
        if (callId.isEmpty || callId != _currentCallId) return;

        add(CallAnswerAcceptedByReceiver(
          callId: callId,
          callType: _currentCallType,
          signalData: _currentSignalData ?? const <String, dynamic>{},
        ));
        return;
      }

      if (type == 'call_reject' || type == 'call_end') {
        final callId = data['callId']?.toString() ?? '';
        if (callId.isEmpty || callId != _currentCallId) return;

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
      emit(const CallLoading());

      final user = _auth.currentUser;
      if (user == null) {
        emit(const CallError(message: 'User not authenticated'));
        return;
      }

      final response = await _apiService.post(ApiEndpoints.callInitiate, {
        'callerId': user.uid,
        'receiverId': event.receiverId,
        'bookingId': event.bookingId,
        'callType': event.callType,
        'callerName': user.displayName ?? 'User',
        'callerRole': event.receiverRole == AppConstants.roleProvider
            ? AppConstants.roleSeeker
            : AppConstants.roleProvider,
        'callerProfileImageUrl': user.photoURL,
      });

      if (response['success'] != true) {
        emit(CallError(message: response['message']?.toString() ?? 'Failed to initiate call'));
        return;
      }

      final call = response['call'] as Map<String, dynamic>;
      final signalData = (response['signalData'] is Map<String, dynamic>)
          ? response['signalData'] as Map<String, dynamic>
          : <String, dynamic>{};

      _currentCallId = call['id']?.toString() ?? '';
      _currentCallType = event.callType;
      _otherUserId = event.receiverId;
      _otherUserName = event.receiverName;
      _otherUserRole = event.receiverRole;
      _otherUserProfileImageUrl = event.receiverProfileImageUrl;
      _currentSignalData = signalData;
      _isLocalParticipantConnected = false;
      _pendingRemoteUid = null;

      emit(CallInitiated(
        callId: _currentCallId ?? '',
        receiverId: event.receiverId,
        receiverName: _otherUserName,
        receiverRole: _otherUserRole,
        receiverProfileImageUrl: _otherUserProfileImageUrl,
        callType: event.callType,
        signalData: signalData,
      ));

      await _socketService.send('call_request', {
        'callId': _currentCallId,
        'bookingId': event.bookingId,
        'receiverId': event.receiverId,
        'callType': event.callType,
        'callerName': user.displayName ?? 'User',
        'callerRole': event.receiverRole == AppConstants.roleProvider
            ? AppConstants.roleSeeker
            : AppConstants.roleProvider,
        'callerProfileImageUrl': user.photoURL,
        'signalData': signalData,
      });
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
      _currentCallType = event.signalData['callType']?.toString() ?? AppConstants.callTypeVoice;
      _currentSignalData = event.signalData;
      _isLocalParticipantConnected = false;
      _pendingRemoteUid = null;

      final user = _auth.currentUser;
      if (user == null) {
        emit(const CallError(message: 'User not authenticated'));
        return;
      }

      await _apiService.post(ApiEndpoints.callUpdateStatus, {
        'callId': event.callId,
        'status': 'answered',
        'userId': user.uid,
      });

      await NotificationService().cancelCallNotification(event.callId);

      emit(CallConnecting(
        callId: event.callId,
        callType: _currentCallType,
        isCaller: false,
        otherUserName: _otherUserName,
        otherUserRole: _otherUserRole,
        otherUserProfileImageUrl: _otherUserProfileImageUrl,
      ));

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
    try {
      await _callService.leaveChannel();
      await NotificationService().cancelCallNotification(event.callId);

      final canUpdateBackend = event.callId.isNotEmpty && event.callId != 'pending';
      final user = _auth.currentUser;
      if (canUpdateBackend) {
        await _apiService.post(ApiEndpoints.callUpdateStatus, {
          'callId': event.callId,
          'status': 'ended',
          'duration': event.duration,
          if (user != null) 'userId': user.uid,
        });

        if (_otherUserId.isNotEmpty) {
          await _socketService.send('call_end', {
            'callId': event.callId,
            'targetUserId': _otherUserId,
            'duration': event.duration,
          });
        }
      }

      emit(CallEnded(callId: event.callId, duration: event.duration, reason: 'normal'));
      _resetCallSession();
    } catch (e) {
      emit(CallError(message: 'Failed to end call: $e'));
    }
  }

  Future<void> _onRejectCallRequested(
    RejectCallRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      await NotificationService().cancelCallNotification(event.callId);

      await _apiService.post(ApiEndpoints.callUpdateStatus, {
        'callId': event.callId,
        'status': 'rejected',
        if (_auth.currentUser != null) 'userId': _auth.currentUser!.uid,
      });

      if (_otherUserId.isNotEmpty) {
        await _socketService.send('call_reject', {
          'callId': event.callId,
          'targetUserId': _otherUserId,
        });
      }

      emit(CallEnded(callId: event.callId, duration: 0, reason: 'rejected'));
      _resetCallSession();
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

      emit(CallEnded(callId: event.callId, duration: 0, reason: 'missed'));
      _resetCallSession();
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
      if (state is! CallConnected) {
        emit(const CallError(message: 'Call connection failed. Please try again.'));
      }
      return;
    }

    if (event.state == CallConnectionState.disconnected) {
      _isLocalParticipantConnected = false;
      if (_currentCallId != null && _callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!).inSeconds;

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

        _resetCallSession();
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
    await NotificationService().cancelCallNotification(event.callId);

    _currentCallId = event.callId;
    _currentCallType = event.callType;
    _otherUserId = event.callerId;
    _otherUserName = event.callerName;
    _otherUserRole = event.callerRole;
    _otherUserProfileImageUrl = event.callerProfileImageUrl;
    _currentSignalData = event.signalData;

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

    await _callService.leaveChannel();
    emit(CallEnded(callId: event.callId, duration: event.duration, reason: reason));
    _resetCallSession();
  }

  Future<void> _onLoadCallHistoryRequested(
    LoadCallHistoryRequested event,
    Emitter<CallState> emit,
  ) async {
    try {
      final response = await _apiService.get('/api/calls/history/${event.userId}');

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
