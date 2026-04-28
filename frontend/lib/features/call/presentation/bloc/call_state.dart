import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

abstract class CallState extends Equatable {
  const CallState();

  @override
  List<Object?> get props => [];
}

class CallInitial extends CallState {
  const CallInitial();
}

class CallLoading extends CallState {
  const CallLoading();
}

class CallInitiated extends CallState {
  final String callId;
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String? receiverProfileImageUrl;
  final String callType;
  final Map<String, dynamic> signalData;

  const CallInitiated({
    required this.callId,
    required this.receiverId,
    required this.receiverName,
    this.receiverRole = AppConstants.roleUser,
    this.receiverProfileImageUrl,
    required this.callType,
    required this.signalData,
  });

  @override
  List<Object?> get props => [callId, receiverId, receiverName, receiverRole, receiverProfileImageUrl, callType, signalData];
}

class CallRinging extends CallState {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerRole;
  final String? callerProfileImageUrl;
  final String callType;
  final Map<String, dynamic> signalData;

  const CallRinging({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerRole = AppConstants.roleUser,
    this.callerProfileImageUrl,
    required this.callType,
    required this.signalData,
  });

  @override
  List<Object?> get props => [callId, callerId, callerName, callerRole, callerProfileImageUrl, callType, signalData];
}

class CallConnecting extends CallState {
  final String callId;
  final String callType;
  final bool isCaller;
  final String otherUserName;
  final String otherUserRole;
  final String? otherUserProfileImageUrl;
  final bool isMuted;
  final bool isVideoOn;

  const CallConnecting({
    required this.callId,
    required this.callType,
    required this.isCaller,
    this.otherUserName = '',
    this.otherUserRole = AppConstants.roleUser,
    this.otherUserProfileImageUrl,
    this.isMuted = false,
    this.isVideoOn = true,
  });

  CallConnecting copyWith({bool? isMuted, bool? isVideoOn}) => CallConnecting(
        callId: callId,
        callType: callType,
        isCaller: isCaller,
        otherUserName: otherUserName,
        otherUserRole: otherUserRole,
        otherUserProfileImageUrl: otherUserProfileImageUrl,
        isMuted: isMuted ?? this.isMuted,
        isVideoOn: isVideoOn ?? this.isVideoOn,
      );

  @override
  List<Object?> get props => [callId, callType, isCaller, otherUserName, otherUserRole, otherUserProfileImageUrl, isMuted, isVideoOn];
}

class CallConnected extends CallState {
  final String callId;
  final String callType;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isVideoOn;
  final int? remoteUid;
  final DateTime connectedAt;
  final String otherUserName;
  final String otherUserRole;
  final String? otherUserProfileImageUrl;

  const CallConnected({
    required this.callId,
    required this.callType,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isVideoOn = true,
    this.remoteUid,
    required this.connectedAt,
    this.otherUserName = '',
    this.otherUserRole = AppConstants.roleUser,
    this.otherUserProfileImageUrl,
  });

  CallConnected copyWith({
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isVideoOn,
    int? remoteUid,
  }) {
    return CallConnected(
      callId: callId,
      callType: callType,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      remoteUid: remoteUid ?? this.remoteUid,
      connectedAt: connectedAt,
      otherUserName: otherUserName,
      otherUserRole: otherUserRole,
      otherUserProfileImageUrl: otherUserProfileImageUrl,
    );
  }

  @override
  List<Object?> get props => [
        callId,
        callType,
        isMuted,
        isSpeakerOn,
        isVideoOn,
        remoteUid,
        connectedAt,
        otherUserName,
        otherUserRole,
        otherUserProfileImageUrl,
      ];
}

class CallEnded extends CallState {
  final String callId;
  final int duration;
  final String reason; // 'normal', 'rejected', 'missed', 'error'

  const CallEnded({
    required this.callId,
    required this.duration,
    required this.reason,
  });

  @override
  List<Object?> get props => [callId, duration, reason];
}

class CallHistoryLoaded extends CallState {
  final List<CallHistoryItem> history;

  const CallHistoryLoaded({required this.history});

  @override
  List<Object?> get props => [history];
}

class CallError extends CallState {
  final String message;

  const CallError({required this.message});

  @override
  List<Object?> get props => [message];
}

// Helper class for call history
class CallHistoryItem extends Equatable {
  final String id;
  final String callerId;
  final String callerName;
  final String callerRole;
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String callType;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int duration;

  const CallHistoryItem({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerRole = AppConstants.roleUser,
    required this.receiverId,
    required this.receiverName,
    this.receiverRole = AppConstants.roleUser,
    required this.callType,
    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.duration,
  });

  factory CallHistoryItem.fromJson(Map<String, dynamic> json) {
    return CallHistoryItem(
      id: json['id'] ?? '',
      callerId: json['callerId'] ?? '',
      callerName: json['callerName'] ?? 'Unknown',
      callerRole: json['callerRole'] ?? AppConstants.roleUser,
      receiverId: json['receiverId'] ?? '',
      receiverName: json['receiverName'] ?? 'Unknown',
      receiverRole: json['receiverRole'] ?? AppConstants.roleUser,
      callType: json['callType'] ?? 'voice',
      status: json['status'] ?? 'ended',
      startedAt: DateTime.parse(json['startedAt'] ?? DateTime.now().toIso8601String()),
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
      duration: json['duration'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        callerId,
        callerName,
        callerRole,
        receiverId,
        receiverName,
        receiverRole,
        callType,
        status,
        startedAt,
        endedAt,
        duration,
      ];
}
