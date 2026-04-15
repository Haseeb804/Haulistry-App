import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';

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
  late AnimationController _animationController;
  Timer? _statusPollingTimer;
  bool _navigatedToLiveSession = false;

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
  }

  String _resolveActiveCallId(CallState state) {
    return switch (state) {
      CallInitiated s => s.callId,
      CallConnecting s => s.callId,
      CallConnected s => s.callId,
      _ => widget.callId,
    };
  }

  String _resolveDisplayName(CallState state) {
    return switch (state) {
      CallInitiated s => s.receiverName,
      CallConnecting s => s.otherUserName,
      CallConnected s => s.otherUserName,
      _ => widget.receiverName,
    };
  }

  String _resolveDisplayRole(CallState state) {
    return switch (state) {
      CallInitiated s => s.receiverRole,
      CallConnecting s => s.otherUserRole,
      CallConnected s => s.otherUserRole,
      _ => widget.receiverRole,
    };
  }

  String? _resolveDisplayImage(CallState state) {
    return switch (state) {
      CallInitiated s => s.receiverProfileImageUrl,
      CallConnecting s => s.otherUserProfileImageUrl,
      CallConnected s => s.otherUserProfileImageUrl,
      _ => widget.receiverProfileImageUrl,
    };
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
        
        // Emit event to trigger caller join for the BLoC
        // BLoC will use stored agoraConfig if not provided here
        if (!mounted) return;
        context.read<CallBloc>().add(CallAnswerAcceptedByReceiver(
          callId: callId,
          callType: widget.callType,
          agoraConfig: {}, // Empty; BLoC will use stored config
        ));

        final latestState = context.read<CallBloc>().state;
        final displayName = _resolveDisplayName(latestState);
        final displayRole = _resolveDisplayRole(latestState);
        final displayImage = _resolveDisplayImage(latestState);
        
        final route = widget.callType == AppConstants.callTypeVoice
            ? AppRoutes.callVoice
            : AppRoutes.callVideo;
        if (!mounted) return;
        context.go(route, extra: {
          'callId': callId,
          'otherUserId': widget.receiverId,
          'otherUserName': displayName,
          'otherUserRole': displayRole,
          'otherUserProfileImageUrl': displayImage,
        });
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
          // Navigate to voice or video call screen
            final route = widget.callType == AppConstants.callTypeVoice
              ? AppRoutes.callVoice
              : AppRoutes.callVideo;
          context.go(route, extra: {
            'callId': state.callId,
            'otherUserId': widget.receiverId,
            'otherUserName': state.otherUserName,
            'otherUserRole': state.otherUserRole,
            'otherUserProfileImageUrl': state.otherUserProfileImageUrl,
          });
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
                // Receiver Info with Animated Rings
                Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Animated Rings
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
                        // Avatar
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          backgroundImage: displayImage != null
                            ? NetworkImage(displayImage)
                              : null,
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
                    if (displayRole != AppConstants.roleUser && displayRole.isNotEmpty) ...[
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
                        String statusText = 'Calling...';
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
                // Cancel Button
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

    // Draw three expanding rings
    for (int i = 0; i < 3; i++) {
      final progress = (animation.value + (i * 0.3)) % 1.0;
      final radius = maxRadius * progress;
      final opacity = 1.0 - progress;

      paint.color = color.withOpacity(opacity * 0.5);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_CallingRingsPainter oldDelegate) => true;
}
