import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class AgoraCallService {
  static final AgoraCallService _instance = AgoraCallService._internal();
  factory AgoraCallService() => _instance;
  AgoraCallService._internal();

  late RtcEngine _engine;
  bool _isInitialized = false;
  StreamController<CallState> _callStateController = StreamController<CallState>.broadcast();
  StreamController<RemoteUserState> _remoteUserController = StreamController<RemoteUserState>.broadcast();
  StreamController<int> _volumeController = StreamController<int>.broadcast();

  Stream<CallState> get callStateStream => _callStateController.stream;
  Stream<RemoteUserState> get remoteUserStream => _remoteUserController.stream;
  Stream<int> get volumeStream => _volumeController.stream;

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
          _callStateController.add(CallState.connected);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          _remoteUserController.add(RemoteUserState(remoteUid, true));
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          _remoteUserController.add(RemoteUserState(remoteUid, false));
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          _callStateController.add(CallState.disconnected);
        },
        onError: (ErrorCodeType error, String msg) {
          _callStateController.add(CallState.error);
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

    _callStateController.add(CallState.connecting);
  }

  Future<void> joinVideoCall({
    required String channel,
    required int uid,
    String? token,
  }) async {
    if (!_isInitialized) {
      throw Exception('Agora engine not initialized');
    }

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

    _callStateController.add(CallState.connecting);
  }

  Future<void> leaveChannel() async {
    await _engine.leaveChannel();
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
    _isInitialized = false;
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
