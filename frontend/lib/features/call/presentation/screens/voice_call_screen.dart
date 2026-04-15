import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callId;
  final String otherUserName;
  final String otherUserRole;
  final String? otherUserProfileImageUrl;

  const VoiceCallScreen({
    super.key,
    required this.callId,
    this.otherUserName = '',
    this.otherUserRole = AppConstants.roleUser,
    this.otherUserProfileImageUrl,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  Timer? _durationTimer;
  Timer? _statusPollingTimer;
  Duration _callDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startDurationTimer();
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

  @override
  void dispose() {
    _durationTimer?.cancel();
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

  String _resolveActiveCallId(CallState state) {
    final resolvedId = switch (state) {
      CallConnecting s => s.callId,
      CallConnected s => s.callId,
      CallEnded s => s.callId,
      _ => widget.callId,
    };
    return resolvedId;
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
                  final displayName = widget.otherUserName.isNotEmpty
                      ? widget.otherUserName
                      : 'Voice Call';
                  final displayRole = widget.otherUserRole != AppConstants.roleUser
                      ? widget.otherUserRole
                      : '';

                  return Column(
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

                final displayName = state.otherUserName.isNotEmpty
                    ? state.otherUserName
                    : widget.otherUserName.isNotEmpty
                        ? widget.otherUserName
                        : 'Voice Call';
                final displayRole = state.otherUserRole != AppConstants.roleUser
                    ? state.otherUserRole
                  : widget.otherUserRole != AppConstants.roleUser
                        ? widget.otherUserRole
                        : '';
                final displayImageUrl = state.otherUserProfileImageUrl ?? widget.otherUserProfileImageUrl;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 60),
                    // User Info
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          backgroundImage: displayImageUrl != null
                              ? NetworkImage(displayImageUrl)
                              : null,
                          child: displayImageUrl == null
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
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(_callDuration),
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.8),
                          ),
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
