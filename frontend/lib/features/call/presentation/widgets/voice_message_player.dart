import 'package:flutter/material.dart';
import '../../../../core/services/voice_recorder_service.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final int duration;
  final bool isSentByMe;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.isSentByMe,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final VoiceRecorderService _recorderService = VoiceRecorderService();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(seconds: widget.duration);

    _recorderService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _recorderService.playbackPositionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
  }

  @override
  void dispose() {
    _recorderService.stopPlayback();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isPlaying) {
        await _recorderService.pausePlayback();
      } else {
        if (_currentPosition >= _totalDuration) {
          await _recorderService.stopPlayback();
          setState(() {
            _currentPosition = Duration.zero;
          });
        }
        await _recorderService.playAudio(widget.audioUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play audio: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isSentByMe
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade300;
    final textColor = widget.isSentByMe ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause Button
          _isLoading
              ? SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : IconButton(
                  onPressed: _togglePlayback,
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: textColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
          const SizedBox(width: 8),
          // Waveform Visualization
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform bars
                SizedBox(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(
                      30,
                      (index) {
                        final progress = _totalDuration.inSeconds > 0
                            ? _currentPosition.inSeconds /
                                _totalDuration.inSeconds
                            : 0.0;
                        final isActive = (index / 30) < progress;
                        
                        // Generate varying heights for waveform effect
                        final heights = [
                          0.3, 0.5, 0.7, 0.9, 0.6, 0.4, 0.8, 1.0, 0.7, 0.5,
                          0.6, 0.9, 0.5, 0.7, 0.8, 0.4, 0.6, 0.9, 0.7, 0.5,
                          0.8, 0.6, 0.4, 0.9, 0.7, 0.5, 0.6, 0.8, 0.4, 0.6
                        ];
                        final height = 30.0 * heights[index % heights.length];

                        return Container(
                          width: 2,
                          height: height,
                          decoration: BoxDecoration(
                            color: isActive
                                ? textColor
                                : textColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Duration Text
                Text(
                  '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
