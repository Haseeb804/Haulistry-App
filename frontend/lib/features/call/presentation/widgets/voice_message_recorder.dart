import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/services/voice_recorder_service.dart';

class VoiceMessageRecorder extends StatefulWidget {
  final Function(File audioFile, int duration) onRecordingComplete;

  const VoiceMessageRecorder({
    super.key,
    required this.onRecordingComplete,
  });

  @override
  State<VoiceMessageRecorder> createState() => _VoiceMessageRecorderState();
}

class _VoiceMessageRecorderState extends State<VoiceMessageRecorder>
    with SingleTickerProviderStateMixin {
  final VoiceRecorderService _recorderService = VoiceRecorderService();
  late AnimationController _waveController;
  bool _isRecording = false;
  bool _isCancelled = false;
  Duration _duration = Duration.zero;
  double _slidePosition = 0.0;
  final double _cancelThreshold = -100.0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _recorderService.recordingDurationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      await _recorderService.startRecording();
      setState(() {
        _isRecording = true;
        _isCancelled = false;
        _slidePosition = 0.0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_isCancelled) {
      await _recorderService.cancelRecording();
      setState(() {
        _isRecording = false;
        _isCancelled = false;
        _duration = Duration.zero;
      });
      return;
    }

    final result = await _recorderService.stopRecording();
    if (result != null && result.path != null) {
      widget.onRecordingComplete(
        File(result.path!),
        result.duration.inSeconds,
      );
    }

    setState(() {
      _isRecording = false;
      _duration = Duration.zero;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _slidePosition += details.delta.dx;
      if (_slidePosition > 0) _slidePosition = 0;
      
      if (_slidePosition < _cancelThreshold) {
        _isCancelled = true;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _stopRecording();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRecording) {
      return GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mic,
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onLongPressEnd: (_) => _stopRecording(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isCancelled ? Colors.red.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            // Cancel Indicator
            AnimatedOpacity(
              opacity: _slidePosition < -50 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.cancel,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            // Recording Waveform Animation
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Row(
                  children: List.generate(
                    4,
                    (index) {
                      final offset = (index * 0.2) % 1.0;
                      final value = (_waveController.value + offset) % 1.0;
                      final height = 10 + (15 * (1 - (value - 0.5).abs() * 2));
                      return Container(
                        width: 3,
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: _isCancelled ? Colors.red : Colors.blue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            // Duration
            Text(
              _formatDuration(_duration),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _isCancelled ? Colors.red : Colors.black87,
              ),
            ),
            const Spacer(),
            // Instruction Text
            Text(
              _isCancelled ? 'Release to cancel' : 'Slide to cancel',
              style: TextStyle(
                fontSize: 12,
                color: _isCancelled ? Colors.red : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            // Mic Icon
            Icon(
              Icons.mic,
              color: _isCancelled ? Colors.red : Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}
