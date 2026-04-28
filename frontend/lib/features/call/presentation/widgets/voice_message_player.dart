import 'dart:async';
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
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _playbackPosSub;

  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  bool get _isActivePlayer =>
      _recorderService.currentlyPlayingUrl == widget.audioUrl;

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(seconds: widget.duration);

    _playerStateSub = _recorderService.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        // Only count as playing if this instance's URL is the active one.
        _isPlaying = state == PlayerState.playing && _isActivePlayer;
        if (state == PlayerState.stopped && !_isActivePlayer) {
          // Another player stopped — nothing to reset here.
          return;
        }
        if (state == PlayerState.stopped) {
          _currentPosition = Duration.zero;
        }
      });
    });

    _playbackPosSub = _recorderService.playbackPositionStream.listen((pos) {
      if (!mounted || !_isActivePlayer) return;
      setState(() {
        _currentPosition = pos;
      });
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _playbackPosSub?.cancel();
    // Only stop playback if this player is the one currently active.
    if (_isActivePlayer) {
      _recorderService.stopPlayback();
    }
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    setState(() => _isLoading = true);

    try {
      if (_isPlaying) {
        await _recorderService.pausePlayback();
      } else if (_recorderService.isPaused && _isActivePlayer) {
        // Resume from the current position rather than restarting.
        await _recorderService.resumePlayback();
      } else {
        // Start fresh (new play or switching from another active player).
        await _recorderService.playAudio(widget.audioUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play audio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(30, (index) {
                      final progress = _totalDuration.inMilliseconds > 0
                          ? _currentPosition.inMilliseconds /
                              _totalDuration.inMilliseconds
                          : 0.0;
                      final isActive = (index / 30) < progress;
                      const heights = [
                        0.3, 0.5, 0.7, 0.9, 0.6, 0.4, 0.8, 1.0, 0.7, 0.5,
                        0.6, 0.9, 0.5, 0.7, 0.8, 0.4, 0.6, 0.9, 0.7, 0.5,
                        0.8, 0.6, 0.4, 0.9, 0.7, 0.5, 0.6, 0.8, 0.4, 0.6,
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
                    }),
                  ),
                ),
                const SizedBox(height: 4),
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
