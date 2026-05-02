import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../constants/app_constants.dart';
import 'api_service.dart';
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
  bool _remoteDescriptionSet = false;
  bool _isRestartingIce = false; // prevents double-restart from two failure callbacks

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  Timer? _connectionTimeoutTimer;
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  // Holds a webrtc_offer that arrived before _joinCall() created the peer
  // connection (race: caller sends offer faster than receiver's camera init).
  RTCSessionDescription? _pendingOffer;

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

  /// Starts the local camera and microphone early (e.g. during the outgoing
  /// call ringing phase) so the user sees their own preview before the call
  /// connects.  Safe to call multiple times — a no-op if already running.
  Future<void> startLocalPreview() async {
    if (_localStream != null) return;
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'frameRate': {'ideal': 15},
        },
      });
      localRenderer.srcObject = _localStream;
    } catch (_) {
      // Camera permission denied or unavailable — joinVideoCall() will surface
      // the error when the peer connection is actually created.
    }
  }

  Future<void> _joinCall({required bool videoEnabled}) async {
    if (!_initialized) {
      throw Exception('WebRTC call service not initialized');
    }
    if (_callId == null || _peerUserId == null) {
      throw Exception('Call session is not configured');
    }

    // Close any stale peer connection from a previous call before creating a new one.
    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
      } catch (_) {}
      _peerConnection = null;
    }

    _videoEnabled = videoEnabled;
    _remoteDescriptionSet = false;
    _isRestartingIce = false;
    _pendingIceCandidates.clear();
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

    // Reuse the stream started by startLocalPreview() so we don't request
    // camera permission a second time and avoid a visible camera blink.
    if (_localStream == null) {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
    }

    final iceServers = await _resolveIceServers();

    final configuration = {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    // Pre-create a synthetic remote stream so onTrack can always set
    // remoteRenderer.srcObject — even on Android where event.streams is empty.
    _remoteStream = await createLocalMediaStream('remote_${_callId ?? ""}');

    // Capture peerUserId NOW so cancelSession() clearing _peerUserId doesn't
    // prevent the RemoteUserState from being emitted if onTrack fires late.
    final capturedPeerUserId = _peerUserId;

    _peerConnection!.onTrack = (RTCTrackEvent event) async {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        remoteRenderer.srcObject = _remoteStream;
      } else if (_remoteStream != null) {
        // Android unified-plan delivers tracks without stream wrappers.
        // Add the track to our synthetic stream so the renderer shows video.
        try {
          await _remoteStream!.addTrack(event.track);
        } catch (_) {}
        remoteRenderer.srcObject = _remoteStream;
      }
      // Use the snapshotted peer ID — _peerUserId may be null if cancelSession()
      // ran concurrently (e.g. user hung up while ICE was completing).
      final peer = capturedPeerUserId ?? _peerUserId;
      if (peer != null && peer.isNotEmpty) {
        final uid = peer.hashCode & 0x7fffffff;
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
        _connectionTimeoutTimer?.cancel();
        _isRestartingIce = false;
        _callStateController.add(CallMediaState.connected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        // onIceConnectionState(failed) fires first; only one restart is needed.
        if (!_isRestartingIce) {
          unawaited(_attemptIceRestart());
        }
        _callStateController.add(CallMediaState.disconnected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _callStateController.add(CallMediaState.disconnected);
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        if (!_isRestartingIce) {
          unawaited(_attemptIceRestart());
        }
      }
    };

    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(const Duration(seconds: 30), () {
      final state = _peerConnection?.connectionState;
      if (state != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _callStateController.add(CallMediaState.error);
      }
    });

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
    } else if (_pendingOffer != null) {
      // Receiver: an offer arrived before the peer connection was ready.
      // Now that _peerConnection exists, process it immediately.
      final queued = _pendingOffer!;
      _pendingOffer = null;
      await _handleIncomingOffer(queued.sdp!, null);
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
      final sdp = data['sdp']?.toString();
      if (sdp == null || sdp.isEmpty) return;

      if (_peerConnection == null) {
        // Peer connection not yet created — caller sent the offer faster than
        // the receiver's camera/mic init finished. Queue it; _joinCall() will
        // process it once the connection exists.
        _pendingOffer = RTCSessionDescription(sdp, 'offer');
        return;
      }

      await _handleIncomingOffer(sdp, data['fromUserId']?.toString());
      return;
    }

    if (type == 'webrtc_answer') {
      if (_peerConnection == null) return;
      final sdp = data['sdp']?.toString();
      if (sdp == null || sdp.isEmpty) return;

      await _setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      return;
    }

    if (type == 'webrtc_ice_candidate') {
      if (_peerConnection == null) return;
      final candidate = data['candidate']?.toString();
      if (candidate == null || candidate.isEmpty) return;

      final incoming = RTCIceCandidate(
        candidate,
        data['sdpMid']?.toString(),
        data['sdpMLineIndex'] is int
            ? data['sdpMLineIndex'] as int
            : int.tryParse(data['sdpMLineIndex']?.toString() ?? ''),
      );

      if (_remoteDescriptionSet) {
        await _peerConnection!.addCandidate(incoming);
      } else {
        _pendingIceCandidates.add(incoming);
      }
    }
  }

  Future<void> _setRemoteDescription(RTCSessionDescription description) async {
    if (_peerConnection == null) return;

    await _peerConnection!.setRemoteDescription(description);
    _remoteDescriptionSet = true;

    if (_pendingIceCandidates.isNotEmpty) {
      final pending = List<RTCIceCandidate>.from(_pendingIceCandidates);
      _pendingIceCandidates.clear();
      for (final candidate in pending) {
        await _peerConnection!.addCandidate(candidate);
      }
    }
  }

  /// Processes an incoming SDP offer: sets remote description, creates answer,
  /// and sends it back.  Extracted so both the real-time socket path and the
  /// deferred (_pendingOffer) path share the same logic.
  Future<void> _handleIncomingOffer(String sdp, String? fromUserId) async {
    if (_peerConnection == null) return;

    await _setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _videoEnabled,
    });
    await _peerConnection!.setLocalDescription(answer);

    await _socket.send('webrtc_answer', {
      'callId': _callId,
      'targetUserId': fromUserId ?? _peerUserId,
      'type': answer.type,
      'sdp': answer.sdp,
    });
  }

  Future<List<Map<String, dynamic>>> _resolveIceServers() async {
    try {
      final response = await ApiService.instance.get(ApiEndpoints.turnCredentials);
      final rows = (response['iceServers'] as List<dynamic>? ?? const []);
      final servers = rows
          .whereType<Map>()
          .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
          .where((server) => server.containsKey('urls'))
          .toList();

      if (servers.isNotEmpty) {
        return servers;
      }
    } catch (_) {
      // fallback below
    }

    // Hardcoded Metered TURN servers — TURN is required on symmetric NAT (mobile carriers).
    // STUN-only will silently fail on most Pakistani mobile networks.
    return const [
      {'urls': 'stun:stun.relay.metered.ca:80'},
      {
        'urls': 'turn:global.relay.metered.ca:80',
        'username': '55ebcd964c2936d0dc1db8d2',
        'credential': 'WIir6zhTPXOiW156',
      },
      {
        'urls': 'turn:global.relay.metered.ca:80?transport=tcp',
        'username': '55ebcd964c2936d0dc1db8d2',
        'credential': 'WIir6zhTPXOiW156',
      },
      {
        'urls': 'turn:global.relay.metered.ca:443',
        'username': '55ebcd964c2936d0dc1db8d2',
        'credential': 'WIir6zhTPXOiW156',
      },
      {
        'urls': 'turns:global.relay.metered.ca:443?transport=tcp',
        'username': '55ebcd964c2936d0dc1db8d2',
        'credential': 'WIir6zhTPXOiW156',
      },
    ];
  }

  Future<void> _attemptIceRestart() async {
    if (_peerConnection == null || _peerUserId == null || _callId == null) return;
    if (_isRestartingIce) return;

    _isRestartingIce = true;
    // Reset so incoming ICE candidates from the new negotiation are queued
    // until the new answer's remote description is set.
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    // If the restart doesn't reconnect within 15 s, declare a permanent error
    // so the UI can surface it (rather than hanging silently).
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(const Duration(seconds: 15), () {
      final pc = _peerConnection;
      if (pc != null &&
          pc.connectionState != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _callStateController.add(CallMediaState.error);
      }
    });

    try {
      final offer = await _peerConnection!.createOffer({
        'iceRestart': true,
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': _videoEnabled,
      });
      await _peerConnection!.setLocalDescription(offer);

      await _socket.send('webrtc_offer', {
        'callId': _callId,
        'targetUserId': _peerUserId,
        'type': offer.type,
        'sdp': offer.sdp,
      });
    } catch (_) {
      _isRestartingIce = false;
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
    // setSpeakerphoneOn is a system-level call — invoke once, not per-track.
    // It can throw "Speaker information is not available" on Android after a
    // process restart; catch so the call session is not affected.
    try {
      await Helper.setSpeakerphoneOn(enabled);
    } catch (_) {}
    final tracks = _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    for (final track in tracks) {
      try {
        track.enableSpeakerphone(enabled);
      } catch (_) {}
    }
  }

  // ── Synchronous state accessors ─────────────────────────────────────────────
  // These let a newly-restored call screen read the current WebRTC state
  // without waiting for a stream event (broadcast streams don't replay).

  bool get isConnected =>
      _peerConnection?.connectionState ==
      RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  MediaStream? get remoteStream => _remoteStream;
  MediaStream? get localStream => _localStream;

  /// Re-emit current connection and remote-user state to all active listeners.
  /// Call this from a new screen that was restored mid-call so it catches up
  /// on state that was emitted before it subscribed.
  void rebroadcastState() {
    if (isConnected) {
      _callStateController.add(CallMediaState.connected);
    }
    if (_remoteStream != null && _peerUserId != null && _peerUserId!.isNotEmpty) {
      final uid = _peerUserId!.hashCode & 0x7fffffff;
      _remoteUserController.add(RemoteUserState(uid, true));
    }
  }

  /// Immediately clears session identifiers so any in-flight socket events or
  /// native WebRTC callbacks (ICE restart, etc.) are ignored.  Call this
  /// synchronously before the async cleanup to prevent races.
  void cancelSession() {
    _callId = null;
    _peerUserId = null;
    _remoteDescriptionSet = false;
    _isRestartingIce = false;
    _pendingIceCandidates.clear();
    _pendingOffer = null;
    _remoteStream = null;
  }

  Future<void> leaveChannel() async {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;

    // Null the peer-connection reference FIRST so any callbacks that fire
    // during close() see _peerConnection == null and bail out early.
    final pc = _peerConnection;
    _peerConnection = null;

    cancelSession();

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    _remoteStream = null;

    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;

    try {
      await pc?.close();
    } catch (_) {}

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
