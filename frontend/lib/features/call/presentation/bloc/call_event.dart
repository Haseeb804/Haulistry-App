import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

abstract class CallEvent extends Equatable {
  const CallEvent();

  @override
  List<Object?> get props => [];
}

class InitiateCallRequested extends CallEvent {
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String? receiverProfileImageUrl;
  final String bookingId;
  final String callType; // 'voice' or 'video'

  const InitiateCallRequested({
    required this.receiverId,
    required this.receiverName,
    this.receiverRole = AppConstants.roleUser,
    this.receiverProfileImageUrl,
    required this.bookingId,
    required this.callType,
  });

  @override
  List<Object?> get props => [receiverId, receiverName, receiverRole, receiverProfileImageUrl, bookingId, callType];
}

class AnswerCallRequested extends CallEvent {
  final String callId;
  final Map<String, dynamic> signalData;

  const AnswerCallRequested({
    required this.callId,
    required this.signalData,
  });

  @override
  List<Object?> get props => [callId, signalData];
}

class EndCallRequested extends CallEvent {
  final String callId;
  final int duration;

  const EndCallRequested({
    required this.callId,
    required this.duration,
  });

  @override
  List<Object?> get props => [callId, duration];
}

class RejectCallRequested extends CallEvent {
  final String callId;

  const RejectCallRequested({required this.callId});

  @override
  List<Object?> get props => [callId];
}

class MissedCallReported extends CallEvent {
  final String callId;

  const MissedCallReported({required this.callId});

  @override
  List<Object?> get props => [callId];
}

class ToggleMuteRequested extends CallEvent {
  const ToggleMuteRequested();
}

class ToggleSpeakerRequested extends CallEvent {
  const ToggleSpeakerRequested();
}

class ToggleVideoRequested extends CallEvent {
  const ToggleVideoRequested();
}

class SwitchCameraRequested extends CallEvent {
  const SwitchCameraRequested();
}

class CallStateChanged extends CallEvent {
  final CallConnectionState state;

  const CallStateChanged(this.state);

  @override
  List<Object?> get props => [state];
}

class RemoteUserJoined extends CallEvent {
  final int uid;

  const RemoteUserJoined(this.uid);

  @override
  List<Object?> get props => [uid];
}

class RemoteUserLeft extends CallEvent {
  final int uid;

  const RemoteUserLeft(this.uid);

  @override
  List<Object?> get props => [uid];
}

class IncomingCallReceived extends CallEvent {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerRole;
  final String? callerProfileImageUrl;
  final String callType;
  final Map<String, dynamic> signalData;

  const IncomingCallReceived({
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

class LoadCallHistoryRequested extends CallEvent {
  final String userId;

  const LoadCallHistoryRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class CallAnswerAcceptedByReceiver extends CallEvent {
  final String callId;
  final String callType;
  final Map<String, dynamic> signalData;

  const CallAnswerAcceptedByReceiver({
    required this.callId,
    required this.callType,
    required this.signalData,
  });

  @override
  List<Object?> get props => [callId, callType, signalData];
}

class RemoteCallStatusUpdated extends CallEvent {
  final String callId;
  final String status;
  final int duration;

  const RemoteCallStatusUpdated({
    required this.callId,
    required this.status,
    required this.duration,
  });

  @override
  List<Object?> get props => [callId, status, duration];
}

enum CallConnectionState {
  idle,
  connecting,
  connected,
  disconnected,
  error,
}
