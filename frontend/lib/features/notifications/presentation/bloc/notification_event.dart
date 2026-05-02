import 'package:equatable/equatable.dart';
import '../../../../core/domain/entities/notification_entity.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

class NotificationsLoadRequested extends NotificationEvent {
  final String userId;
  const NotificationsLoadRequested(this.userId);
  @override
  List<Object?> get props => [userId];
}

class NotificationMarkReadRequested extends NotificationEvent {
  final String notificationId;
  const NotificationMarkReadRequested(this.notificationId);
  @override
  List<Object?> get props => [notificationId];
}

class NotificationsMarkAllReadRequested extends NotificationEvent {
  final String userId;
  const NotificationsMarkAllReadRequested(this.userId);
  @override
  List<Object?> get props => [userId];
}

class NotificationReceived extends NotificationEvent {
  final NotificationEntity notification;
  const NotificationReceived(this.notification);
  @override
  List<Object?> get props => [notification];
}
