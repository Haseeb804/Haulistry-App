import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';
import '../../../../core/services/webrtc_call_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/call_identity_resolver.dart';
import '../../../../core/utils/image_helper.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserRole;
  final String? otherUserProfileImageUrl;

  const VideoCallScreen({
    super.key,
    required this.callId,
    this.otherUserId = '',
    this.otherUserName = '',
    this.otherUserRole = AppConstants.roleUser,
    this.otherUserProfileImageUrl,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCCallService _callService = WebRTCCallService();
  // Written by _CallDurationTimer callback; read by end-call buttons. No setState needed.
  Duration _callDuration = Duration.zero;
  bool _showControls = true;
  Timer? _controlsTimer;
  CallParticipantIdentity? _resolvedOtherUser;

  @override
  void initState() {
    super.initState();
    _startControlsTimer();
    // Only fetch from API when widget doesn't already carry the identity info.
    if (widget.otherUserName.isEmpty || widget.otherUserProfileImageUrl == null) {
      _resolveOtherUserIdentity();
    }
  }

  Future<void> _resolveOtherUserIdentity() async {
    final resolved = await CallIdentityResolver.resolveParticipant(
      userId: widget.otherUserId,
      fallbackName: widget.otherUserName,
      fallbackRole: widget.otherUserRole,
      fallbackProfileImageUrl: widget.otherUserProfileImageUrl,
      defaultLabel: 'Video Call',
    );
    if (mounted) {
      setState(() {
        _resolvedOtherUser = resolved;
      });
    }
  }

  void _startControlsTimer() {
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _resetControlsTimer() {
    setState(() => _showControls = true);
    _controlsTimer?.cancel();
    _startControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    super.dispose();
  }

  String _resolveActiveCallId(CallState state) {
    return switch (state) {
      CallConnecting s => s.callId,
      CallConnected s => s.callId,
      CallEnded s => s.callId,
      _ => widget.callId,
    };
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
                final cs = state is CallConnecting ? state as CallConnecting : null;
                final displayName = CallIdentityResolver.resolveDisplayName(
                  preferredName: cs?.otherUserName,
                  fallbackName: _resolvedOtherUser?.displayName ?? widget.otherUserName,
                  defaultLabel: 'Video Call',
                );
                final displayRole = CallIdentityResolver.resolveRole(
                  preferredRole: cs?.otherUserRole,
                  fallbackRole: _resolvedOtherUser?.role ?? widget.otherUserRole,
                );
                final displayImageUrl = CallIdentityResolver.resolveProfileImageUrl(
                  preferredImageUrl: cs?.otherUserProfileImageUrl,
                  fallbackImageUrl: _resolvedOtherUser?.profileImageUrl ?? widget.otherUserProfileImageUrl,
                );

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
                              foregroundImage: ImageHelper.providerFor(displayImageUrl),
                              onForegroundImageError: displayImageUrl != null
                                  ? (_, __) {}
                                  : null,
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
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
                            _CallDurationTimer(onTick: (d) => _callDuration = d),
                            const SizedBox(height: 8),
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
                              final activeCallId = _resolveActiveCallId(context.read<CallBloc>().state);
                              context.read<CallBloc>().add(
                                    EndCallRequested(
                                      callId: activeCallId,
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
                    RTCVideoView(_callService.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                  else
                    Builder(builder: (context) {
                      final remoteImageUrl = CallIdentityResolver.resolveProfileImageUrl(
                        preferredImageUrl: state.otherUserProfileImageUrl,
                        fallbackImageUrl: _resolvedOtherUser?.profileImageUrl ?? widget.otherUserProfileImageUrl,
                      );
                      final remoteName = CallIdentityResolver.resolveDisplayName(
                        preferredName: state.otherUserName,
                        fallbackName: _resolvedOtherUser?.displayName ?? widget.otherUserName,
                        defaultLabel: 'Video Call',
                      );
                      return Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white24,
                              foregroundImage: ImageHelper.providerFor(remoteImageUrl),
                              onForegroundImageError: remoteImageUrl != null
                                  ? (_, __) {}
                                  : null,
                              child: Text(
                                remoteName.isNotEmpty ? remoteName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              CallIdentityResolver.resolveDisplayName(
                                preferredName: state.otherUserName,
                                fallbackName: _resolvedOtherUser?.displayName ?? widget.otherUserName,
                                defaultLabel: 'Waiting for other person...',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (CallIdentityResolver.resolveRole(
                                  preferredRole: state.otherUserRole,
                                  fallbackRole: _resolvedOtherUser?.role ?? widget.otherUserRole,
                                ) !=
                                AppConstants.roleUser) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  () {
                                    final role = CallIdentityResolver.resolveRole(
                                      preferredRole: state.otherUserRole,
                                      fallbackRole: _resolvedOtherUser?.role ?? widget.otherUserRole,
                                    );
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
                    );
                    }),
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
                            ? RTCVideoView(_callService.localRenderer, mirror: true)
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
                        child: _CallDurationTimer(
                          onTick: (d) => _callDuration = d,
                          textStyle: const TextStyle(
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
                                  final activeCallId = _resolveActiveCallId(context.read<CallBloc>().state);
                                  context.read<CallBloc>().add(
                                        EndCallRequested(
                                          callId: activeCallId,
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

// Isolated timer widget — only this widget rebuilds every second.
class _CallDurationTimer extends StatefulWidget {
  final void Function(Duration)? onTick;
  final TextStyle? textStyle;
  const _CallDurationTimer({this.onTick, this.textStyle});

  @override
  State<_CallDurationTimer> createState() => _CallDurationTimerState();
}

class _CallDurationTimerState extends State<_CallDurationTimer> {
  Duration _duration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _duration = Duration(seconds: _duration.inSeconds + 1));
      widget.onTick?.call(_duration);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) return '${p(d.inHours)}:${p(d.inMinutes.remainder(60))}:${p(d.inSeconds.remainder(60))}';
    return '${p(d.inMinutes.remainder(60))}:${p(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _format(_duration),
      style: widget.textStyle ??
          TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.8)),
    );
  }
}
