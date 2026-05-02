import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/call_minimize_service.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_state.dart';

/// Green top bar shown when a call is minimized (WhatsApp-style).
/// Place this inside a Stack at the top of the app (see main.dart).
class FloatingCallBar extends StatefulWidget {
  const FloatingCallBar({super.key});

  @override
  State<FloatingCallBar> createState() => _FloatingCallBarState();
}

class _FloatingCallBarState extends State<FloatingCallBar> {
  Timer? _timer;
  DateTime? _connectedAt;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startOrUpdateTimer(DateTime connectedAt) {
    if (_connectedAt == connectedAt) return;
    _connectedAt = connectedAt;
    _timer?.cancel();
    _elapsed = DateTime.now().difference(connectedAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(connectedAt));
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours.toString().padLeft(2, '0')}:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CallMinimizeService.instance.isMinimized,
      builder: (context, isMinimized, _) {
        if (!isMinimized) {
          _timer?.cancel();
          _connectedAt = null;
          return const SizedBox.shrink();
        }

        return BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            String displayName = 'Call';
            String callType = AppConstants.callTypeVoice;
            bool showTimer = false;

            if (state is CallConnected) {
              displayName = state.otherUserName.isNotEmpty ? state.otherUserName : 'Call';
              callType = state.callType;
              _startOrUpdateTimer(state.connectedAt);
              showTimer = true;
            } else if (state is CallConnecting) {
              displayName = state.otherUserName.isNotEmpty ? state.otherUserName : 'Call';
              callType = state.callType;
            } else {
              _timer?.cancel();
              _connectedAt = null;
              return const SizedBox.shrink();
            }

            final isVideo = callType == AppConstants.callTypeVideo;

            return GestureDetector(
              onTap: () {
                // Read identity from CallMinimizeService — it was stored when
                // _minimizeAndPop() was called, so it's always consistent and
                // doesn't depend on BLoC state timing during restore.
                final svc = CallMinimizeService.instance;
                final callId = svc.callId;
                final otherUserName = svc.otherUserName.isNotEmpty ? svc.otherUserName : displayName;
                final otherUserRole = svc.otherUserRole.isNotEmpty ? svc.otherUserRole : AppConstants.roleUser;
                final otherUserProfileImageUrl = svc.otherUserProfileImageUrl;

                // Push the call screen BEFORE calling restore() so the
                // navigation context is still valid.  The call screen's own
                // initState() calls restore(), hiding the bar at the right time.
                context.push(
                  isVideo ? AppRoutes.callVideo : AppRoutes.callVoice,
                  extra: {
                    'callId': callId,
                    'otherUserId': '',
                    'otherUserName': otherUserName,
                    'otherUserRole': otherUserRole,
                    'otherUserProfileImageUrl': otherUserProfileImageUrl,
                  },
                );
              },
              child: Container(
                color: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Icon(
                        isVideo ? Icons.videocam : Icons.phone_in_talk,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showTimer)
                        Text(
                          _formatDuration(_elapsed),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.expand_less, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
