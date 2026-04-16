import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'realtime_socket_service.dart';

class WebRTCCallService {
  WebRTCCallService._internal();

  static final WebRTCCallService _instance = WebRTCCallService._internal();
  factory WebRTCCallService() => _instance;

  final RealtimeSocketService _socket = RealtimeSocketService();

  final StreamController<CallMediaState> _callStateController =
      StreamController<CallMediaState>.broadcast();
  final StreamController<RemoteUserState> _remoteUserController =
      StreamController<RemoteUserState>.broadcast();

  Stream<CallMediaState> get callStateStream => _callStateController.stream;
  Stream<RemoteUserState> get remoteUserStream => _remoteUserController.stream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _initialized = false;
  bool _videoEnabled = false;
  String? _callId;
  String? _peerUserId;
  bool _isCaller = false;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  Future<void> initialize() async {
    if (_initialized) return;

    await localRenderer.initialize();
    await remoteRenderer.initialize();

    await _socket.connect();

    _socketSubscription = _socket.events.listen(_onSocketEvent);

    _initialized = true;
  }

  Future<void> configureSession({
    required String callId,
    required String peerUserId,
    required bool isCaller,
  }) async {
    _callId = callId;
    _peerUserId = peerUserId;
    _isCaller = isCaller;
  }

  Future<void> joinVoiceCall() async {
    await _joinCall(videoEnabled: false);
  }

  Future<void> joinVideoCall() async {
    await _joinCall(videoEnabled: true);
  }

  Future<void> _joinCall({required bool videoEnabled}) async {
    if (!_initialized) {
      throw Exception('WebRTC call service not initialized');
    }
    if (_callId == null || _peerUserId == null) {
      throw Exception('Call session is not configured');
    }

    _videoEnabled = videoEnabled;
    _callStateController.add(CallMediaState.connecting);

    final mediaConstraints = {
      'audio': true,
      'video': videoEnabled
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
              'frameRate': {'ideal': 15},
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    localRenderer.srcObject = _localStream;

    const configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        final uid = _peerUserId.hashCode & 0x7fffffff;
        _remoteUserController.add(RemoteUserState(uid, true));
      }
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
      if (_peerUserId == null || _callId == null) return;
      await _socket.send('webrtc_ice_candidate', {
        'callId': _callId,
        'targetUserId': _peerUserId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _callStateController.add(CallMediaState.connected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _callStateController.add(CallMediaState.disconnected);
      }
    };

    if (_isCaller) {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': videoEnabled,
      });
      await _peerConnection!.setLocalDescription(offer);

      await _socket.send('webrtc_offer', {
        'callId': _callId,
        'targetUserId': _peerUserId,
        'type': offer.type,
        'sdp': offer.sdp,
      });
    }
  }

  Future<void> _onSocketEvent(Map<String, dynamic> event) async {
    final type = event['type']?.toString() ?? '';
    final data = (event['data'] is Map<String, dynamic>)
        ? event['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final callId = data['callId']?.toString();
    if (callId != null && _callId != null && callId != _callId) return;

    if (type == 'webrtc_offer') {
      if (_peerConnection == null) return;

      final sdp = data['sdp']?.toString();
      if (sdp == null || sdp.isEmpty) return;

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, 'offer'),
      );

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': _videoEnabled,
      });
      await _peerConnection!.setLocalDescription(answer);

      await _socket.send('webrtc_answer', {
        'callId': _callId,
        'targetUserId': data['fromUserId']?.toString() ?? _peerUserId,
        'type': answer.type,
        'sdp': answer.sdp,
      });
      return;
    }

    if (type == 'webrtc_answer') {
      if (_peerConnection == null) return;
      final sdp = data['sdp']?.toString();
      if (sdp == null || sdp.isEmpty) return;

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, 'answer'),
      );
      return;
    }

    if (type == 'webrtc_ice_candidate') {
      if (_peerConnection == null) return;
      final candidate = data['candidate']?.toString();
      if (candidate == null || candidate.isEmpty) return;

      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          candidate,
          data['sdpMid']?.toString(),
          data['sdpMLineIndex'] is int ? data['sdpMLineIndex'] as int : int.tryParse(data['sdpMLineIndex']?.toString() ?? ''),
        ),
      );
    }
  }

  Future<void> muteLocalAudio(bool muted) async {
    if (_localStream == null) return;
    for (final t in _localStream!.getAudioTracks()) {
      t.enabled = !muted;
    }
  }

  Future<void> muteLocalVideo(bool muted) async {
    if (_localStream == null) return;
    for (final t in _localStream!.getVideoTracks()) {
      t.enabled = !muted;
    }
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final tracks = _localStream!.getVideoTracks();
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  Future<void> enableSpeakerphone(bool enabled) async {
    final tracks = _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    for (final track in tracks) {
      await Helper.setSpeakerphoneOn(enabled);
      track.enableSpeakerphone(enabled);
    }
  }

  Future<void> leaveChannel() async {
    try {
      await _peerConnection?.close();
    } catch (_) {}

    _peerConnection = null;

    try {
      await _localStream?.dispose();
    } catch (_) {}

    _localStream = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    _callStateController.add(CallMediaState.disconnected);
  }

  Future<void> dispose() async {
    await leaveChannel();
    await _socketSubscription?.cancel();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    _initialized = false;
  }
}

enum CallMediaState {
  idle,
  connecting,
  connected,
  disconnected,
  error,
}

class RemoteUserState {
  final int uid;
  final bool isJoined;

  RemoteUserState(this.uid, this.isJoined);
}
