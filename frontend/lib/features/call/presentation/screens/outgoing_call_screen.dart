import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String callId;
  final String receiverName;
  final String receiverRole;
  final String? receiverProfileImageUrl;
  final String callType;

  const OutgoingCallScreen({
    super.key,
    required this.callId,
    required this.receiverName,
    this.receiverRole = 'user',
    this.receiverProfileImageUrl,
    required this.callType,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallBloc, CallState>(
      listener: (context, state) {
        if (state is CallConnected) {
          // Navigate to voice or video call screen
          final route = widget.callType == 'voice' ? '/call/voice' : '/call/video';
          context.go(route, extra: {
            'callId': widget.callId,
            'otherUserName': widget.receiverName,
            'otherUserRole': widget.receiverRole,
            'otherUserProfileImageUrl': widget.receiverProfileImageUrl,
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
                          backgroundImage: widget.receiverProfileImageUrl != null
                              ? NetworkImage(widget.receiverProfileImageUrl!)
                              : null,
                          child: widget.receiverProfileImageUrl == null
                              ? Text(
                                  widget.receiverName.isNotEmpty
                                      ? widget.receiverName[0].toUpperCase()
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
                      widget.receiverName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.receiverRole != 'user' && widget.receiverRole.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.receiverRole[0].toUpperCase() + widget.receiverRole.substring(1),
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
                      context.read<CallBloc>().add(
                            EndCallRequested(
                              callId: widget.callId,
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
