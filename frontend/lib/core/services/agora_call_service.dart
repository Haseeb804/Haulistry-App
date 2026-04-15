import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class AgoraCallService {
  static final AgoraCallService _instance = AgoraCallService._internal();
  factory AgoraCallService() => _instance;
  AgoraCallService._internal();

  late RtcEngine _engine;
  bool _isInitialized = false;
  CallState _currentCallState = CallState.idle;
  String? _activeChannel;
  int? _activeUid;
  final StreamController<CallState> _callStateController = StreamController<CallState>.broadcast();
  final StreamController<RemoteUserState> _remoteUserController = StreamController<RemoteUserState>.broadcast();
  final StreamController<int> _volumeController = StreamController<int>.broadcast();
  final StreamController<void> _tokenExpiryController = StreamController<void>.broadcast();

  Stream<CallState> get callStateStream => _callStateController.stream;
  Stream<RemoteUserState> get remoteUserStream => _remoteUserController.stream;
  Stream<int> get volumeStream => _volumeController.stream;
  Stream<void> get tokenExpiryStream => _tokenExpiryController.stream;
  String? get activeChannel => _activeChannel;
  int? get activeUid => _activeUid;

  void _setCallState(CallState state) {
    print('[AgoraCallService] setState: $state');
    _currentCallState = state;
    _callStateController.add(state);
  }

  Future<void> initialize(String appId) async {
    if (_isInitialized) return;

    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    // Create Agora engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Register event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('[AgoraCallService] onJoinChannelSuccess: connection=${connection.channelId}, uid=${connection.localUid}');
          _setCallState(CallState.connected);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('[AgoraCallService] onUserJoined: remoteUid=$remoteUid');
          _remoteUserController.add(RemoteUserState(remoteUid, true));
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print('[AgoraCallService] onUserOffline: remoteUid=$remoteUid');
          _remoteUserController.add(RemoteUserState(remoteUid, false));
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          print('[AgoraCallService] onLeaveChannel');
          _setCallState(CallState.disconnected);
        },
        onError: (ErrorCodeType error, String msg) {
          print('[AgoraCallService] onError: error=$error, msg=$msg');
          _setCallState(CallState.error);
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          print('[AgoraCallService] onTokenPrivilegeWillExpire');
          _tokenExpiryController.add(null);
        },
        onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int speakerNumber, int totalVolume) {
          if (speakers.isNotEmpty) {
            _volumeController.add(speakers.first.volume ?? 0);
          }
        },
      ),
    );

    _isInitialized = true;
  }

  Future<void> joinVoiceCall({
    required String channel,
    required int uid,
    String? token,
  }) async {
    if (!_isInitialized) {
      throw Exception('Agora engine not initialized');
    }

    print('[AgoraCallService] joinVoiceCall: channel=$channel, uid=$uid, token=${token?.length ?? 0}, token_empty=${token?.isEmpty ?? true}');

    // Enable audio
    await _engine.enableAudio();
    await _engine.enableLocalAudio(true);

    
    // Set audio profile for voice call
    await _engine.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    // Enable volume indication
    await _engine.enableAudioVolumeIndication(
      interval: 200,
      smooth: 3,
      reportVad: true,
    );

    _setCallState(CallState.connecting);
    _activeChannel = channel;
    _activeUid = uid;

    // Join channel
    await _engine.joinChannel(
      token: token ?? '',
      channelId: channel,
      uid: uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    // Add connection timeout (30 seconds)
    Future.delayed(const Duration(seconds: 30), () {
      if (_currentCallState == CallState.connecting) {
        _setCallState(CallState.error);
      }
    });
  }

  Future<void> joinVideoCall({
    required String channel,
    required int uid,
    String? token,
  }) async {
    if (!_isInitialized) {
      throw Exception('Agora engine not initialized');
    }

    print('[AgoraCallService] joinVideoCall: channel=$channel, uid=$uid, token=${token?.length ?? 0}, token_empty=${token?.isEmpty ?? true}');

    // Enable audio and video
    await _engine.enableAudio();
    await _engine.enableVideo();

    await _engine.enableLocalAudio(true);
    await _engine.enableLocalVideo(true);

    // Set video configuration
    await _engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 480),
        frameRate: 15,
        bitrate: 0,
      ),
    );

    // Start local preview so camera renders immediately
    await _engine.startPreview();

    _setCallState(CallState.connecting);
    _activeChannel = channel;
    _activeUid = uid;

    // Join channel
    await _engine.joinChannel(
      token: token ?? '',
      channelId: channel,
      uid: uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );

    // Add connection timeout (30 seconds)
    Future.delayed(const Duration(seconds: 30), () {
      if (_currentCallState == CallState.connecting) {
        _setCallState(CallState.error);
      }
    });
  }

  Future<void> leaveChannel() async {
    await _engine.leaveChannel();
    _activeChannel = null;
    _activeUid = null;
    _setCallState(CallState.disconnected);
  }

  Future<void> renewToken(String token) async {
    await _engine.renewToken(token);
  }

  Future<void> muteLocalAudio(bool muted) async {
    await _engine.muteLocalAudioStream(muted);
  }

  Future<void> muteLocalVideo(bool muted) async {
    await _engine.muteLocalVideoStream(muted);
  }

  Future<void> switchCamera() async {
    await _engine.switchCamera();
  }

  Future<void> enableSpeakerphone(bool enabled) async {
    await _engine.setEnableSpeakerphone(enabled);
  }

  Future<void> dispose() async {
    await _engine.leaveChannel();
    await _engine.release();
    await _callStateController.close();
    await _remoteUserController.close();
    await _volumeController.close();
    await _tokenExpiryController.close();
    _isInitialized = false;
    _currentCallState = CallState.idle;
    _activeChannel = null;
    _activeUid = null;
  }

  RtcEngine get engine => _engine;
}

enum CallState {
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
