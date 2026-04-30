import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  // Local loading flag so the spinner is shown while the API call is in flight
  // without polluting the shared CallBloc state with CallLoading.
  bool _isLoading = true;

  void _loadHistory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      setState(() => _isLoading = true);
      context.read<CallBloc>().add(LoadCallHistoryRequested(userId: uid));
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    // BlocListener sits at Scaffold level so it can call setState on the
    // enclosing State and dismiss the loading spinner.
    return BlocListener<CallBloc, CallState>(
      listenWhen: (_, current) =>
          current is CallHistoryLoaded || current is CallError,
      listener: (context, state) {
        if (mounted) setState(() => _isLoading = false);
      },
      child: Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _loadHistory,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.call_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Call History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Recent calls',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // buildWhen prevents call-signaling events (CallRinging, CallConnecting,
          // etc.) from wiping out the loaded history list while the user is
          // reading it.
          BlocBuilder<CallBloc, CallState>(
            buildWhen: (_, current) =>
                current is CallHistoryLoaded || current is CallError,
            builder: (context, state) {
              if (_isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (state is CallError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadHistory,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is! CallHistoryLoaded || state.history.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No call history',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your call logs will appear here',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = state.history[index];
                      return _CallLogTile(item: item);
                    },
                    childCount: state.history.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ));
  }
}

class _CallLogTile extends StatelessWidget {
  final CallHistoryItem item;

  const _CallLogTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isCaller = item.callerId == currentUid;
    final otherName = isCaller ? item.receiverName : item.callerName;
    final otherRole = isCaller ? item.receiverRole : item.callerRole;
    final otherImageUrl = isCaller ? item.receiverProfileImageUrl : item.callerProfileImageUrl;
    final otherUserId = isCaller ? item.receiverId : item.callerId;

    final statusColor = _statusColor(item.status);
    final statusIcon = _statusIcon(item.status, isCaller);
    final statusLabel = _statusLabel(item.status, isCaller);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showCallOptions(context, otherUserId, otherName, otherRole, otherImageUrl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    foregroundImage: ImageHelper.providerFor(otherImageUrl),
                    onForegroundImageError: otherImageUrl != null ? (_, __) {} : null,
                    child: Text(
                      otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(statusIcon, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTimestamp(item.startedAt),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          item.callType == AppConstants.callTypeVideo
                              ? Icons.videocam_rounded
                              : Icons.phone_rounded,
                          size: 13,
                          color: Colors.grey[500],
                        ),
                        if (item.duration > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(item.duration),
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                    if (otherRole.isNotEmpty && otherRole != AppConstants.roleUser) ...[
                      const SizedBox(height: 2),
                      Text(
                        otherRole[0].toUpperCase() + otherRole.substring(1),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Quick re-call button
              if (item.bookingId != null && item.bookingId!.isNotEmpty)
                IconButton(
                  icon: Icon(
                    item.callType == AppConstants.callTypeVideo
                        ? Icons.videocam_rounded
                        : Icons.phone_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: () => _initiateCall(context, otherUserId, otherName, otherRole,
                      otherImageUrl, item.callType, item.bookingId!),
                  tooltip: 'Call back',
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCallOptions(
    BuildContext context,
    String otherUserId,
    String otherName,
    String otherRole,
    String? otherImageUrl,
  ) {
    if (item.bookingId == null || item.bookingId!.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              otherName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(item.startedAt),
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallOptionButton(
                  icon: Icons.phone_rounded,
                  label: 'Voice Call',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(ctx);
                    _initiateCall(context, otherUserId, otherName, otherRole, otherImageUrl,
                        AppConstants.callTypeVoice, item.bookingId!);
                  },
                ),
                _CallOptionButton(
                  icon: Icons.videocam_rounded,
                  label: 'Video Call',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(ctx);
                    _initiateCall(context, otherUserId, otherName, otherRole, otherImageUrl,
                        AppConstants.callTypeVideo, item.bookingId!);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _initiateCall(
    BuildContext context,
    String otherUserId,
    String otherName,
    String otherRole,
    String? otherImageUrl,
    String callType,
    String bookingId,
  ) {
    context.read<CallBloc>().add(
          InitiateCallRequested(
            receiverId: otherUserId,
            receiverName: otherName,
            receiverRole: otherRole,
            receiverProfileImageUrl: otherImageUrl,
            bookingId: bookingId,
            callType: callType,
          ),
        );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ended':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'rejected':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status, bool isCaller) {
    switch (status.toLowerCase()) {
      case 'ended':
        return isCaller ? Icons.call_made_rounded : Icons.call_received_rounded;
      case 'missed':
        return Icons.call_missed_rounded;
      case 'rejected':
        return Icons.call_missed_outgoing_rounded;
      default:
        return Icons.call_rounded;
    }
  }

  String _statusLabel(String status, bool isCaller) {
    switch (status.toLowerCase()) {
      case 'ended':
        return isCaller ? 'Outgoing' : 'Incoming';
      case 'missed':
        return 'Missed';
      case 'rejected':
        return 'Declined';
      default:
        return status;
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('dd MMM').format(dt);
  }
}

class _CallOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallOptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
