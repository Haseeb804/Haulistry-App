import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';
import '../../../../core/services/agora_call_service.dart' as agora;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String otherUserName;
  final String otherUserRole;
  final String? otherUserProfileImageUrl;

  const VideoCallScreen({
    super.key,
    required this.callId,
    this.otherUserName = '',
    this.otherUserRole = AppConstants.roleUser,
    this.otherUserProfileImageUrl,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Timer? _durationTimer;
  Timer? _statusPollingTimer;
  Duration _callDuration = Duration.zero;
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _startDurationTimer();
    _startControlsTimer();
    _statusPollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollCallStatus(),
    );
  }

  Future<void> _pollCallStatus() async {
    if (!mounted) return;

    try {
      final response = await ApiService.instance.get(ApiEndpoints.callById(widget.callId));
      if (response['success'] != true || response['call'] == null) return;

      final call = response['call'] as Map<String, dynamic>;
      final status = (call['status'] as String? ?? '').toLowerCase();

      if (status == AppConstants.callStatusRejected ||
          status == AppConstants.callStatusMissed ||
          status == AppConstants.callStatusEnded) {
        if (!mounted) return;
        context.read<CallBloc>().add(
              EndCallRequested(
                callId: widget.callId,
                duration: _callDuration.inSeconds,
              ),
            );
      }
    } catch (_) {
      // Keep call UI running during transient API errors.
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
      });
    });
  }

  void _startControlsTimer() {
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _resetControlsTimer() {
    setState(() {
      _showControls = true;
    });
    _controlsTimer?.cancel();
    _startControlsTimer();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _controlsTimer?.cancel();
    _statusPollingTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    }
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallBloc, CallState>(
      listener: (context, state) {
        if (state is CallEnded) {
          context.pop();
        } else if (state is CallError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          context.pop();
        }
      },
      child: Scaffold(
        body: GestureDetector(
          onTap: _resetControlsTimer,
          child: BlocBuilder<CallBloc, CallState>(
            builder: (context, state) {
              if (state is! CallConnected) {
                final displayName = widget.otherUserName.isNotEmpty
                    ? widget.otherUserName
                    : 'Video Call';
                final displayRole = widget.otherUserRole != AppConstants.roleUser
                    ? widget.otherUserRole
                    : '';

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 60),
                        Column(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              backgroundImage: widget.otherUserProfileImageUrl != null
                                  ? NetworkImage(widget.otherUserProfileImageUrl!)
                                  : null,
                              child: widget.otherUserProfileImageUrl == null
                                  ? Text(
                                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (displayRole.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  displayRole[0].toUpperCase() + displayRole.substring(1),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Connecting video call...',
                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: FloatingActionButton.extended(
                            onPressed: () {
                              context.read<CallBloc>().add(
                                    EndCallRequested(
                                      callId: widget.callId,
                                      duration: _callDuration.inSeconds,
                                    ),
                                  );
                            },
                            backgroundColor: Colors.red,
                            icon: const Icon(Icons.call_end),
                            label: const Text('End Call'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  // Remote Video View
                  if (state.remoteUid != null)
                    AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: agora.AgoraCallService().engine,
                        canvas: VideoCanvas(uid: state.remoteUid),
                        connection: const RtcConnection(),
                      ),
                    )
                  else
                    Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white24,
                              backgroundImage: (state.otherUserProfileImageUrl ?? widget.otherUserProfileImageUrl) != null
                                  ? NetworkImage((state.otherUserProfileImageUrl ?? widget.otherUserProfileImageUrl)!)
                                  : null,
                              child: (state.otherUserProfileImageUrl ?? widget.otherUserProfileImageUrl) == null
                                  ? Text(
                                      (state.otherUserName.isNotEmpty
                                              ? state.otherUserName
                                              : widget.otherUserName.isNotEmpty
                                                  ? widget.otherUserName
                                                  : '?')[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              state.otherUserName.isNotEmpty
                                  ? state.otherUserName
                                  : widget.otherUserName.isNotEmpty
                                      ? widget.otherUserName
                                      : 'Waiting for other person...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if ((state.otherUserRole != AppConstants.roleUser && state.otherUserRole.isNotEmpty) ||
                              (widget.otherUserRole != AppConstants.roleUser && widget.otherUserRole.isNotEmpty)) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  () {
                                    final role = state.otherUserRole != AppConstants.roleUser ? state.otherUserRole : widget.otherUserRole;
                                    return role[0].toUpperCase() + role.substring(1);
                                  }(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            const Text(
                              'Connecting...',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Local Video Preview
                  Positioned(
                    top: 48,
                    right: 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 120,
                        height: 160,
                        child: state.isVideoOn
                            ? AgoraVideoView(
                                controller: VideoViewController(
                                  rtcEngine: agora.AgoraCallService().engine,
                                  canvas: const VideoCanvas(uid: 0),
                                ),
                              )
                            : Container(
                                color: Colors.black87,
                                child: const Icon(
                                  Icons.videocam_off,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                              ),
                      ),
                    ),
                  ),
                  // Call Duration
                  if (_showControls)
                    Positioned(
                      top: 48,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatDuration(_callDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  // Call Controls
                  if (_showControls)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Mute Button
                                  _VideoCallControlButton(
                                    icon: state.isMuted ? Icons.mic_off : Icons.mic,
                                    isActive: state.isMuted,
                                    onPressed: () {
                                      context.read<CallBloc>().add(
                                            const ToggleMuteRequested(),
                                          );
                                    },
                                  ),
                                  // Video Toggle Button
                                  _VideoCallControlButton(
                                    icon: state.isVideoOn
                                        ? Icons.videocam
                                        : Icons.videocam_off,
                                    isActive: !state.isVideoOn,
                                    onPressed: () {
                                      context.read<CallBloc>().add(
                                            const ToggleVideoRequested(),
                                          );
                                    },
                                  ),
                                  // Switch Camera Button
                                  _VideoCallControlButton(
                                    icon: Icons.cameraswitch,
                                    isActive: false,
                                    onPressed: () {
                                      context.read<CallBloc>().add(
                                            const SwitchCameraRequested(),
                                          );
                                    },
                                  ),
                                  // Speaker Button
                                  _VideoCallControlButton(
                                    icon: state.isSpeakerOn
                                        ? Icons.volume_up
                                        : Icons.volume_down,
                                    isActive: state.isSpeakerOn,
                                    onPressed: () {
                                      context.read<CallBloc>().add(
                                            const ToggleSpeakerRequested(),
                                          );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // End Call Button
                              FloatingActionButton.extended(
                                onPressed: () {
                                  context.read<CallBloc>().add(
                                        EndCallRequested(
                                          callId: widget.callId,
                                          duration: _callDuration.inSeconds,
                                        ),
                                      );
                                },
                                backgroundColor: Colors.red,
                                icon: const Icon(Icons.call_end),
                                label: const Text('End Call'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VideoCallControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  const _VideoCallControlButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 28,
      style: IconButton.styleFrom(
        backgroundColor: isActive
            ? Colors.red.withOpacity(0.8)
            : Colors.white.withOpacity(0.3),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(16),
      ),
    );
  }
}
