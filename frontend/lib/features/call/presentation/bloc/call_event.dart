import 'package:equatable/equatable.dart';

abstract class CallEvent extends Equatable {
  const CallEvent();

  @override
  List<Object?> get props => [];
}

class InitiateCallRequested extends CallEvent {
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String bookingId;
  final String callType; // 'voice' or 'video'

  const InitiateCallRequested({
    required this.receiverId,
    required this.receiverName,
    this.receiverRole = 'user',
    required this.bookingId,
    required this.callType,
  });

  @override
  List<Object?> get props => [receiverId, receiverName, receiverRole, bookingId, callType];
}

class AnswerCallRequested extends CallEvent {
  final String callId;
  final Map<String, dynamic> agoraConfig;

  const AnswerCallRequested({
    required this.callId,
    required this.agoraConfig,
  });

  @override
  List<Object?> get props => [callId, agoraConfig];
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
  final String callType;
  final Map<String, dynamic> agoraConfig;

  const IncomingCallReceived({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerRole = 'user',
    required this.callType,
    required this.agoraConfig,
  });

  @override
  List<Object?> get props => [callId, callerId, callerName, callerRole, callType, agoraConfig];
}

class LoadCallHistoryRequested extends CallEvent {
  final String userId;

  const LoadCallHistoryRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

enum CallConnectionState {
  idle,
  connecting,
  connected,
  disconnected,
  error,
}
