import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/call_identity_resolver.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String callId;
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String? receiverProfileImageUrl;
  final String callType;

  const OutgoingCallScreen({
    super.key,
    required this.callId,
    this.receiverId = '',
    required this.receiverName,
    this.receiverRole = AppConstants.roleUser,
    this.receiverProfileImageUrl,
    required this.callType,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Timer? _statusPollingTimer;
  bool _navigatedToLiveSession = false;
  CallParticipantIdentity? _resolvedReceiver;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _statusPollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollCallStatus();
    });

    _resolveReceiverIdentity();
  }

  Future<void> _resolveReceiverIdentity() async {
    final resolved = await CallIdentityResolver.resolveParticipant(
      userId: widget.receiverId,
      fallbackName: widget.receiverName,
      fallbackRole: widget.receiverRole,
      fallbackProfileImageUrl: widget.receiverProfileImageUrl,
      defaultLabel: widget.receiverName.isNotEmpty ? widget.receiverName : 'User',
    );

    if (!mounted) return;
    setState(() {
      _resolvedReceiver = resolved;
    });
  }

  String _resolveActiveCallId(CallState state) {
    return switch (state) {
      CallInitiated(:final callId) => callId,
      CallConnecting(:final callId) => callId,
      CallConnected(:final callId) => callId,
      _ => widget.callId,
    };
  }

  String _otherUserName(CallState state) {
    return switch (state) {
      CallInitiated(:final receiverName) => receiverName,
      CallConnecting(:final otherUserName) => otherUserName,
      CallConnected(:final otherUserName) => otherUserName,
      _ => widget.receiverName,
    };
  }

  String _otherUserRole(CallState state) {
    return switch (state) {
      CallInitiated(:final receiverRole) => receiverRole,
      CallConnecting(:final otherUserRole) => otherUserRole,
      CallConnected(:final otherUserRole) => otherUserRole,
      _ => widget.receiverRole,
    };
  }

  String? _otherUserImage(CallState state) {
    return switch (state) {
      CallInitiated(:final receiverProfileImageUrl) => receiverProfileImageUrl,
      CallConnecting(:final otherUserProfileImageUrl) => otherUserProfileImageUrl,
      CallConnected(:final otherUserProfileImageUrl) => otherUserProfileImageUrl,
      _ => widget.receiverProfileImageUrl,
    };
  }

  String _resolveDisplayName(CallState state) {
    return CallIdentityResolver.resolveDisplayName(
      preferredName: _otherUserName(state),
      fallbackName: _resolvedReceiver?.displayName ?? widget.receiverName,
      defaultLabel: widget.receiverName.isNotEmpty ? widget.receiverName : 'User',
    );
  }

  String _resolveDisplayRole(CallState state) {
    return CallIdentityResolver.resolveRole(
      preferredRole: _otherUserRole(state),
      fallbackRole: _resolvedReceiver?.role ?? widget.receiverRole,
    );
  }

  String? _resolveDisplayImage(CallState state) {
    return CallIdentityResolver.resolveProfileImageUrl(
      preferredImageUrl: _otherUserImage(state),
      fallbackImageUrl: _resolvedReceiver?.profileImageUrl ?? widget.receiverProfileImageUrl,
    );
  }

  void _navigateToLiveCall(BuildContext context, String callId, CallState state) {
    final route = widget.callType == AppConstants.callTypeVoice
        ? AppRoutes.callVoice
        : AppRoutes.callVideo;

    context.go(route, extra: {
      'callId': callId,
      'otherUserId': widget.receiverId,
      'otherUserName': _resolveDisplayName(state),
      'otherUserRole': _resolveDisplayRole(state),
      'otherUserProfileImageUrl': _resolveDisplayImage(state),
    });
  }

  Future<void> _pollCallStatus() async {
    if (!mounted) return;

    final state = context.read<CallBloc>().state;
    if (state is CallConnected || state is CallEnded || state is CallError) {
      return;
    }

    final callId = _resolveActiveCallId(state);
    if (callId.isEmpty || callId == 'pending') return;

    try {
      final response = await ApiService.instance.get(ApiEndpoints.callById(callId));
      if (response['success'] != true || response['call'] == null) return;

      final call = response['call'] as Map<String, dynamic>;
      final status = (call['status'] as String? ?? '').toLowerCase();

      if (status == 'answered' && !_navigatedToLiveSession) {
        _navigatedToLiveSession = true;

        if (!mounted) return;
        context.read<CallBloc>().add(
              CallAnswerAcceptedByReceiver(
                callId: callId,
                callType: widget.callType,
                agoraConfig: const {},
              ),
            );

        if (!mounted) return;
        _navigateToLiveCall(context, callId, context.read<CallBloc>().state);
        return;
      }

      if (status == AppConstants.callStatusRejected ||
          status == AppConstants.callStatusMissed ||
          status == AppConstants.callStatusEnded) {
        if (!mounted) return;
        context.read<CallBloc>().add(
              EndCallRequested(
                callId: callId,
                duration: 0,
              ),
            );
      }
    } catch (_) {
      // Keep outgoing screen alive during transient network failures.
    }
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocState = context.watch<CallBloc>().state;
    final displayName = _resolveDisplayName(blocState);
    final displayRole = _resolveDisplayRole(blocState);
    final displayImage = _resolveDisplayImage(blocState);

    return BlocListener<CallBloc, CallState>(
      listener: (context, state) {
        if (state is CallConnected) {
          _navigateToLiveCall(context, state.callId, state);
        } else if (state is CallEnded) {
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 60),
                Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: const Size(200, 200),
                              painter: _CallingRingsPainter(
                                animation: _animationController,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            );
                          },
                        ),
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          backgroundImage:
                              displayImage != null ? NetworkImage(displayImage) : null,
                          child: displayImage == null
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ],
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
                    if (displayRole.isNotEmpty && displayRole != AppConstants.roleUser) ...[
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
                    BlocBuilder<CallBloc, CallState>(
                      builder: (context, state) {
                        var statusText = 'Calling...';
                        if (state is CallConnecting) {
                          statusText = 'Connecting...';
                        }
                        return Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: FloatingActionButton(
                    onPressed: () {
                      final activeCallId = _resolveActiveCallId(context.read<CallBloc>().state);
                      context.read<CallBloc>().add(
                            EndCallRequested(
                              callId: activeCallId,
                              duration: 0,
                            ),
                          );
                    },
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.call_end, size: 32),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallingRingsPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _CallingRingsPainter({
    required this.animation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = color;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (var i = 0; i < 3; i++) {
      final progress = (animation.value + (i * 0.3)) % 1.0;
      final radius = maxRadius * progress;
      final opacity = 1.0 - progress;

      paint.color = color.withOpacity(opacity * 0.5);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CallingRingsPainter oldDelegate) => true;
}
