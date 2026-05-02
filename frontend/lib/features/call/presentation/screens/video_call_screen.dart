import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';
import '../../../../core/services/call_minimize_service.dart';
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
  // Set once on first CallConnected build; passed to timer so restore keeps correct elapsed time.
  Duration? _timerInitialDuration;

  // Direct WebRTC subscriptions — bypass BLoC timing delays so the remote
  // video appears the instant onTrack fires, regardless of bloc event queue.
  StreamSubscription<RemoteUserState>? _remoteUserSub;
  StreamSubscription<CallMediaState>? _callStateSub;
  bool _hasRemoteVideo = false;
  bool _isWebRTCConnected = false;

  @override
  void initState() {
    super.initState();
    // Ensure the floating bar hides when this screen is (re-)pushed.
    CallMinimizeService.instance.restore();
    _startControlsTimer();
    // Only fetch from API when widget doesn't already carry the identity info.
    if (widget.otherUserName.isEmpty || widget.otherUserProfileImageUrl == null) {
      _resolveOtherUserIdentity();
    }
    _subscribeToWebRTC();
  }

  void _subscribeToWebRTC() {
    // Read current WebRTC state synchronously so a restored screen immediately
    // reflects the live connection rather than waiting for a stream replay
    // (broadcast streams don't replay past events).
    _hasRemoteVideo = _callService.remoteRenderer.srcObject != null;
    _isWebRTCConnected = _callService.isConnected;

    _remoteUserSub = _callService.remoteUserStream.listen((user) {
      if (!mounted) return;
      setState(() => _hasRemoteVideo = user.isJoined);
    });

    _callStateSub = _callService.callStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _isWebRTCConnected = s == CallMediaState.connected);
    });

    // Re-bind renderer srcObjects after the first frame so the new RTCVideoView
    // surfaces (created fresh on restore) actually receive frames.  When the
    // previous call screen was popped its native SurfaceTexture was destroyed;
    // the renderer still holds the stream reference but renders to a dead
    // surface.  Setting srcObject = null then restoring it forces the renderer
    // to bind to the new surface created by the fresh RTCVideoView widget.
    if (_isWebRTCConnected || _hasRemoteVideo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final remote = _callService.remoteStream;
        _callService.remoteRenderer.srcObject = null;
        _callService.remoteRenderer.srcObject = remote;

        final local = _callService.localStream;
        _callService.localRenderer.srcObject = null;
        _callService.localRenderer.srcObject = local;

        // Re-broadcast so BLoC listeners (remoteUid, isMuted etc.) in the
        // rebuilt screen also receive a fresh Connected event.
        _callService.rebroadcastState();
      });
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
    _remoteUserSub?.cancel();
    _callStateSub?.cancel();
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

  /// Minimize the video call to the floating bar so the user can use other
  /// screens (tracking, chat, etc.) while the call continues.
  void _minimizeAndPop(BuildContext context) {
    final state = context.read<CallBloc>().state;
    final callId = _resolveActiveCallId(state);

    final name = switch (state) {
      CallConnected s when s.otherUserName.isNotEmpty => s.otherUserName,
      CallConnecting s when s.otherUserName.isNotEmpty => s.otherUserName,
      _ => _resolvedOtherUser?.displayName ?? widget.otherUserName,
    };
    final role = switch (state) {
      CallConnected s => s.otherUserRole,
      CallConnecting s => s.otherUserRole,
      _ => _resolvedOtherUser?.role ?? widget.otherUserRole,
    };
    final imageUrl = switch (state) {
      CallConnected s => s.otherUserProfileImageUrl,
      CallConnecting s => s.otherUserProfileImageUrl,
      _ => _resolvedOtherUser?.profileImageUrl ?? widget.otherUserProfileImageUrl,
    };

    CallMinimizeService.instance.minimize(
      callId: callId,
      callType: AppConstants.callTypeVideo,
      otherUserName: name,
      otherUserRole: role,
      otherUserProfileImageUrl: imageUrl,
    );
    if (context.mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Back gesture → minimize to floating bar instead of ending the call.
        _minimizeAndPop(context);
      },
      child: BlocListener<CallBloc, CallState>(
        listener: (context, state) {
          if (state is CallEnded) {
            CallMinimizeService.instance.clear();
            context.pop();
          } else if (state is CallError) {
            CallMinimizeService.instance.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            context.pop();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _resetControlsTimer,
          child: BlocBuilder<CallBloc, CallState>(
            builder: (context, state) {
              // Show the video stack as soon as WebRTC reports connected via the
              // direct subscription (_isWebRTCConnected), OR when BLoC emits
              // CallConnected — whichever fires first.
              final showVideoStack = state is CallConnected || _isWebRTCConnected;

              if (!showVideoStack) {
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

                final isMuted = cs?.isMuted ?? false;
                final isVideoOn = cs?.isVideoOn ?? true;

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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Minimize call',
                                icon: const Icon(Icons.expand_more, color: Colors.white, size: 28),
                                onPressed: () => _minimizeAndPop(context),
                              ),
                            ],
                          ),
                        ),
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
                            const SizedBox(height: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _VideoCallControlButton(
                                    icon: isMuted ? Icons.mic_off : Icons.mic,
                                    isActive: isMuted,
                                    onPressed: () => context.read<CallBloc>().add(const ToggleMuteRequested()),
                                  ),
                                  _VideoCallControlButton(
                                    icon: isVideoOn ? Icons.videocam : Icons.videocam_off,
                                    isActive: !isVideoOn,
                                    onPressed: () => context.read<CallBloc>().add(const ToggleVideoRequested()),
                                  ),
                                  _VideoCallControlButton(
                                    icon: Icons.cameraswitch,
                                    isActive: false,
                                    onPressed: () => context.read<CallBloc>().add(const SwitchCameraRequested()),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
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
                      ],
                    ),
                  ),
                );
              }

              // Extract per-state values so the video stack works in both
              // CallConnected (normal) and the WebRTC-connected-but-BLoC-lagging case.
              final bool isMuted = switch (state) {
                CallConnected s => s.isMuted,
                CallConnecting s => s.isMuted,
                _ => false,
              };
              final bool isVideoOn = switch (state) {
                CallConnected s => s.isVideoOn,
                CallConnecting s => s.isVideoOn,
                _ => true,
              };
              final bool isSpeakerOn = state is CallConnected ? (state as CallConnected).isSpeakerOn : true;
              final DateTime connectedAt = state is CallConnected
                  ? (state as CallConnected).connectedAt
                  : DateTime.now();
              // These fields exist on both CallConnected and CallConnecting but not on
              // the abstract CallState — extract with switch so Dart's type system is happy.
              final String stateOtherUserName = switch (state) {
                CallConnected s => s.otherUserName,
                CallConnecting s => s.otherUserName,
                _ => widget.otherUserName,
              };
              final String stateOtherUserRole = switch (state) {
                CallConnected s => s.otherUserRole,
                CallConnecting s => s.otherUserRole,
                _ => widget.otherUserRole,
              };
              final String? stateOtherUserProfileImageUrl = switch (state) {
                CallConnected s => s.otherUserProfileImageUrl,
                CallConnecting s => s.otherUserProfileImageUrl,
                _ => widget.otherUserProfileImageUrl,
              };

              // Compute timer offset once so restore keeps the correct elapsed time.
              _timerInitialDuration ??= DateTime.now().difference(connectedAt);

              return Stack(
                children: [
                  // Remote Video View — always in the tree so the renderer can
                  // display frames the moment they arrive, independent of BLoC
                  // state. An avatar overlay sits on top until the first frame.
                  Positioned.fill(
                    child: RTCVideoView(
                      _callService.remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                  // Avatar placeholder shown until remote stream is active.
                  // Uses the direct WebRTC subscription (_hasRemoteVideo) so it
                  // disappears the instant onTrack fires — no BLoC timing delay.
                  if (!_hasRemoteVideo)
                    Positioned.fill(
                    child: Builder(builder: (context) {
                      final remoteImageUrl = CallIdentityResolver.resolveProfileImageUrl(
                        preferredImageUrl: stateOtherUserProfileImageUrl,
                        fallbackImageUrl: _resolvedOtherUser?.profileImageUrl ?? widget.otherUserProfileImageUrl,
                      );
                      final remoteName = CallIdentityResolver.resolveDisplayName(
                        preferredName: stateOtherUserName,
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
                                preferredName: stateOtherUserName,
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
                                  preferredRole: stateOtherUserRole,
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
                                      preferredRole: stateOtherUserRole,
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
                    })),
                  // Local Video Preview
                  Positioned(
                    top: 48,
                    right: 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 120,
                        height: 160,
                        child: isVideoOn
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
                  // Minimize button — always visible (not toggled with controls)
                  // so user can always escape to tracking screen during a call.
                  Positioned(
                    top: 40,
                    left: 8,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _minimizeAndPop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.expand_more, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
                  // Call Duration
                  if (_showControls)
                    Positioned(
                      top: 48,
                      left: 64,
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
                          initialDuration: _timerInitialDuration ?? Duration.zero,
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
                                    icon: isMuted ? Icons.mic_off : Icons.mic,
                                    isActive: isMuted,
                                    onPressed: () {
                                      context.read<CallBloc>().add(
                                            const ToggleMuteRequested(),
                                          );
                                    },
                                  ),
                                  // Video Toggle Button
                                  _VideoCallControlButton(
                                    icon: isVideoOn
                                        ? Icons.videocam
                                        : Icons.videocam_off,
                                    isActive: !isVideoOn,
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
                                    icon: isSpeakerOn
                                        ? Icons.volume_up
                                        : Icons.volume_down,
                                    isActive: isSpeakerOn,
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
  final Duration initialDuration;
  const _CallDurationTimer({this.onTick, this.textStyle, this.initialDuration = Duration.zero});

  @override
  State<_CallDurationTimer> createState() => _CallDurationTimerState();
}

class _CallDurationTimerState extends State<_CallDurationTimer> {
  late Duration _duration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _duration = widget.initialDuration;
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
