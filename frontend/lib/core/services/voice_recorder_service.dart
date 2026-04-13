import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class VoiceRecorderService {
  static final VoiceRecorderService _instance = VoiceRecorderService._internal();
  factory VoiceRecorderService() => _instance;
  VoiceRecorderService._internal();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  
  final StreamController<RecorderState> _recorderStateController = StreamController<RecorderState>.broadcast();
  final StreamController<PlayerState> _playerStateController = StreamController<PlayerState>.broadcast();
  final StreamController<Duration> _recordingDurationController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _playbackPositionController = StreamController<Duration>.broadcast();
  
  Stream<RecorderState> get recorderStateStream => _recorderStateController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<Duration> get recordingDurationStream => _recordingDurationController.stream;
  Stream<Duration> get playbackPositionStream => _playbackPositionController.stream;

  String? _currentRecordingPath;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  Future<void> initialize() async {
    if (_isRecorderInitialized && _isPlayerInitialized) return;

    // Request microphone permission
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('Microphone permission not granted');
    }

    // Initialize recorder
    if (!_isRecorderInitialized) {
      await _recorder.openRecorder();
      _isRecorderInitialized = true;
    }

    // Initialize player
    if (!_isPlayerInitialized) {
      await _player.openPlayer();
      _isPlayerInitialized = true;

      // Listen to player state changes
      _player.onProgress!.listen((event) {
        _playbackPositionController.add(event.position);
        
        if (event.position >= event.duration) {
          _playerStateController.add(PlayerState.stopped);
        }
      });
    }
  }

  Future<String> startRecording() async {
    if (!_isRecorderInitialized) {
      await initialize();
    }

    // Generate file path
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingPath = '${directory.path}/voice_message_$timestamp.m4a';

    // Start recording
    await _recorder.startRecorder(
      toFile: _currentRecordingPath,
      codec: Codec.aacMP4,
    );

    _recorderStateController.add(RecorderState.recording);
    
    // Start duration timer
    _recordingDuration = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _recordingDuration = Duration(milliseconds: _recordingDuration.inMilliseconds + 100);
      _recordingDurationController.add(_recordingDuration);
    });

    return _currentRecordingPath!;
  }

  Future<RecordingResult?> stopRecording() async {
    if (!_recorder.isRecording) return null;

    await _recorder.stopRecorder();
    _recordingTimer?.cancel();
    _recorderStateController.add(RecorderState.stopped);

    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        return RecordingResult(
          path: _currentRecordingPath!,
          duration: _recordingDuration,
        );
      }
    }

    return null;
  }

  Future<void> cancelRecording() async {
    if (_recorder.isRecording) {
      await _recorder.stopRecorder();
      _recordingTimer?.cancel();
      _recorderStateController.add(RecorderState.stopped);

      // Delete the file
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
        _currentRecordingPath = null;
      }
    }
  }

  Future<void> playAudio(String path) async {
    if (!_isPlayerInitialized) {
      await initialize();
    }

    // Stop current playback if any
    if (_player.isPlaying) {
      await _player.stopPlayer();
    }

    await _player.startPlayer(
      fromURI: path,
      codec: Codec.aacMP4,
      whenFinished: () {
        _playerStateController.add(PlayerState.stopped);
      },
    );

    _playerStateController.add(PlayerState.playing);
  }

  Future<void> pausePlayback() async {
    if (_player.isPlaying) {
      await _player.pausePlayer();
      _playerStateController.add(PlayerState.paused);
    }
  }

  Future<void> resumePlayback() async {
    if (_player.isPaused) {
      await _player.resumePlayer();
      _playerStateController.add(PlayerState.playing);
    }
  }

  Future<void> stopPlayback() async {
    if (_player.isPlaying || _player.isPaused) {
      await _player.stopPlayer();
      _playerStateController.add(PlayerState.stopped);
    }
  }

  Future<void> seekTo(Duration position) async {
    if (_player.isPlaying || _player.isPaused) {
      await _player.seekToPlayer(position);
    }
  }

  bool get isRecording => _recorder.isRecording;
  bool get isPlaying => _player.isPlaying;
  bool get isPaused => _player.isPaused;

  Future<void> dispose() async {
    _recordingTimer?.cancel();
    
    if (_recorder.isRecording) {
      await _recorder.stopRecorder();
    }
    await _recorder.closeRecorder();

    if (_player.isPlaying) {
      await _player.stopPlayer();
    }
    await _player.closePlayer();

    await _recorderStateController.close();
    await _playerStateController.close();
    await _recordingDurationController.close();
    await _playbackPositionController.close();

    _isRecorderInitialized = false;
    _isPlayerInitialized = false;
  }
}

enum RecorderState {
  idle,
  recording,
  stopped,
}

enum PlayerState {
  idle,
  playing,
  paused,
  stopped,
}

class RecordingResult {
  final String path;
  final Duration duration;

  RecordingResult({
    required this.path,
    required this.duration,
  });
}
