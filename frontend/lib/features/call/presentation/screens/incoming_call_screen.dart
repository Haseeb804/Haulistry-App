import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';

class IncomingCallScreen extends StatelessWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerRole;
  final String? callerProfileImageUrl;
  final String callType;
  final Map<String, dynamic> agoraConfig;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerRole = 'user',
    this.callerProfileImageUrl,
    required this.callType,
    required this.agoraConfig,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallBloc, CallState>(
      listener: (context, state) {
        if (state is CallConnecting) {
          // Navigate to voice or video call screen
          final route = callType == 'voice' ? '/call/voice' : '/call/video';
          context.go(route, extra: {
            'callId': callId,
            'otherUserName': callerName,
            'otherUserRole': callerRole,
            'otherUserProfileImageUrl': callerProfileImageUrl,
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
                // Caller Info
                Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage: callerProfileImageUrl != null
                          ? NetworkImage(callerProfileImageUrl!)
                          : null,
                      child: callerProfileImageUrl == null
                          ? Text(
                              callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
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
                      callerName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (callerRole != 'user' && callerRole.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          callerRole[0].toUpperCase() + callerRole.substring(1),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          callType == 'voice' ? Icons.phone : Icons.videocam,
                          color: Colors.white.withOpacity(0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Incoming ${callType == 'voice' ? 'voice' : 'video'} call',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Call Actions
                Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline Button
                      _CallActionButton(
                        icon: Icons.call_end,
                        label: 'Decline',
                        backgroundColor: Colors.red,
                        onPressed: () {
                          context.read<CallBloc>().add(
                                RejectCallRequested(callId: callId),
                              );
                        },
                      ),
                      // Accept Button
                      _CallActionButton(
                        icon: Icons.call,
                        label: 'Accept',
                        backgroundColor: Colors.green,
                        onPressed: () {
                          context.read<CallBloc>().add(
                                AnswerCallRequested(
                                  callId: callId,
                                  agoraConfig: agoraConfig,
                                ),
                              );
                        },
                      ),
                    ],
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

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          heroTag: label,
          child: Icon(icon, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
