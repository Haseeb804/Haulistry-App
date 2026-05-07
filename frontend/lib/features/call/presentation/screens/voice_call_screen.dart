import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/call_minimize_service.dart';
import '../../../../core/utils/call_identity_resolver.dart';
import '../../../../core/utils/image_helper.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserRole;
  final String? otherUserProfileImageUrl;

  const VoiceCallScreen({
    super.key,
    required this.callId,
    this.otherUserId = '',
    this.otherUserName = '',
    this.otherUserRole = AppConstants.roleUser,
    this.otherUserProfileImageUrl,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  CallParticipantIdentity? _resolvedOtherUser;
  // Written by _CallDurationTimer callback; read by end-call buttons. No setState needed.
  Duration _callDuration = Duration.zero;
  // Authoritative call-start timestamp — set once from BLoC's connectedAt.
  // Timer initialDuration is computed as DateTime.now().difference(_callConnectedAt)
  // each time the widget is created, so restore/rebuild never resets to 00:00.
  DateTime? _callConnectedAt;

  @override
  void initState() {
    super.initState();
    // Ensure the floating bar hides when this screen is (re-)pushed.
    CallMinimizeService.instance.restore();
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
      defaultLabel: 'Voice Call',
    );
    if (mounted) {
      setState(() {
        _resolvedOtherUser = resolved;
      });
    }
  }

  String _resolveActiveCallId(CallState state) {
    final resolvedId = switch (state) {
      CallConnecting s => s.callId,
      CallConnected s => s.callId,
      CallEnded s => s.callId,
      _ => widget.callId,
    };
    return resolvedId;
  }

  /// Minimize the call to the floating bar so the user can use other screens
  /// (tracking, chat, etc.) while the call continues in the background.
  void _minimizeAndPop(BuildContext context) {
    final state = context.read<CallBloc>().state;
    final callId = _resolveActiveCallId(state);
    final callType = AppConstants.callTypeVoice;

    // Snapshot identity from whichever source is most up-to-date.
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
      callType: callType,
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
        body: Container(
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
            child: BlocBuilder<CallBloc, CallState>(
              builder: (context, state) {
                if (state is! CallConnected) {
                  final cs = state is CallConnecting ? state as CallConnecting : null;
                  final displayName = CallIdentityResolver.resolveDisplayName(
                    preferredName: cs?.otherUserName,
                    fallbackName: _resolvedOtherUser?.displayName ?? widget.otherUserName,
                    defaultLabel: 'Voice Call',
                  );
                  final displayRole = CallIdentityResolver.resolveRole(
                    preferredRole: cs?.otherUserRole,
                    fallbackRole: _resolvedOtherUser?.role ?? widget.otherUserRole,
                  );
                  final displayImageUrl = CallIdentityResolver.resolveProfileImageUrl(
                    preferredImageUrl: cs?.otherUserProfileImageUrl,
                    fallbackImageUrl: _resolvedOtherUser?.profileImageUrl ?? widget.otherUserProfileImageUrl,
                  );

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CallTopBar(onMinimize: () => _minimizeAndPop(context)),
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
                                'Connecting...',
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
                            final state = context.read<CallBloc>().state;
                            final activeCallId = _resolveActiveCallId(state);
                            
                            // Defensive: always try to end call even if callId seems empty
                            if (activeCallId.isNotEmpty) {
                              context.read<CallBloc>().add(
                                    EndCallRequested(
                                      callId: activeCallId,
                                      duration: _callDuration.inSeconds,
                                    ),
                                  );
                            } else {
                              // Fallback: use widget callId
                              context.read<CallBloc>().add(
                                    EndCallRequested(
                                      callId: widget.callId,
                                      duration: _callDuration.inSeconds,
                                    ),
                                  );
                              // Immediately pop since we might not get a clean state transition
                              if (mounted) context.pop();
                            }
                          },
                          backgroundColor: Colors.red,
                          icon: const Icon(Icons.call_end),
                          label: const Text('End Call'),
                        ),
                      ),
                    ],
                  );
                }

                // Pin the authoritative call-start time once from BLoC state.
                _callConnectedAt ??= state.connectedAt;

                final displayName = state.otherUserName.isNotEmpty
                    ? state.otherUserName
                    : CallIdentityResolver.resolveDisplayName(
                        preferredName: _resolvedOtherUser?.displayName,
                        fallbackName: widget.otherUserName,
                        defaultLabel: 'Voice Call',
                      );
                final displayRole = CallIdentityResolver.resolveRole(
                  preferredRole: state.otherUserRole,
                  fallbackRole: _resolvedOtherUser?.role ?? widget.otherUserRole,
                );
                final displayImageUrl = CallIdentityResolver.resolveProfileImageUrl(
                  preferredImageUrl: state.otherUserProfileImageUrl,
                  fallbackImageUrl: _resolvedOtherUser?.profileImageUrl ?? widget.otherUserProfileImageUrl,
                );

                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CallTopBar(onMinimize: () => _minimizeAndPop(context)),
                    // User Info
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
                        const SizedBox(height: 8),
                        _CallDurationTimer(
                          // Compute current elapsed time from the pinned start
                          // timestamp so re-created widgets never show 00:00.
                          initialDuration: _callConnectedAt != null
                              ? DateTime.now().difference(_callConnectedAt!)
                              : Duration.zero,
                          onTick: (d) => _callDuration = d,
                        ),
                        const SizedBox(height: 24),
                        // Volume Indicator
                        if (state.remoteUid != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.volume_up,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Connected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    // Call Controls
                    Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Mute Button
                              _CallControlButton(
                                icon: state.isMuted ? Icons.mic_off : Icons.mic,
                                label: state.isMuted ? 'Unmute' : 'Mute',
                                isActive: state.isMuted,
                                onPressed: () {
                                  context.read<CallBloc>().add(
                                        const ToggleMuteRequested(),
                                      );
                                },
                              ),
                              // Speaker Button
                              _CallControlButton(
                                icon: state.isSpeakerOn
                                    ? Icons.volume_up
                                    : Icons.volume_down,
                                label: 'Speaker',
                                isActive: state.isSpeakerOn,
                                onPressed: () {
                                  context.read<CallBloc>().add(
                                        const ToggleSpeakerRequested(),
                                      );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
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
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _CallTopBar extends StatelessWidget {
  final VoidCallback onMinimize;
  const _CallTopBar({required this.onMinimize});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Minimize call',
            icon: const Icon(Icons.expand_more, color: Colors.white, size: 28),
            onPressed: onMinimize,
          ),
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: 32,
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? Colors.white.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// Isolated timer widget — only this widget rebuilds every second.
class _CallDurationTimer extends StatefulWidget {
  final void Function(Duration)? onTick;
  final Duration initialDuration;
  const _CallDurationTimer({this.onTick, this.initialDuration = Duration.zero});

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
      style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.8)),
    );
  }
}
