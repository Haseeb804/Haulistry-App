import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'notification_event.dart';
import 'notification_state.dart';
import '../../../../core/domain/entities/notification_entity.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/realtime_socket_service.dart';
import '../../../../core/constants/app_constants.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final ApiService _api;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  String? _currentUserId;

  NotificationBloc({ApiService? api})
      : _api = api ?? ApiService.instance,
        super(const NotificationsInitial()) {
    on<NotificationsLoadRequested>(_onLoad);
    on<NotificationMarkReadRequested>(_onMarkRead);
    on<NotificationsMarkAllReadRequested>(_onMarkAllRead);
    on<NotificationReceived>(_onReceived);
  }

  void subscribeToSocket(String userId) {
    _currentUserId = userId;
    _socketSub?.cancel();
    _socketSub = RealtimeSocketService().events.listen((event) {
      if (event['type'] == 'notification') {
        final data = event['data'];
        if (data is Map<String, dynamic> && data['userId']?.toString() == userId) {
          add(NotificationReceived(NotificationEntity.fromJson(data)));
        }
      }
    });
  }

  Future<void> _onLoad(
    NotificationsLoadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationsLoading());
    try {
      final response = await _api.get(ApiEndpoints.notifications(event.userId));
      final list = (response['notifications'] as List<dynamic>? ?? [])
          .map((e) => NotificationEntity.fromJson(e as Map<String, dynamic>))
          .toList();
      final unread = list.where((n) => !n.isRead).length;
      emit(NotificationsLoaded(notifications: list, unreadCount: unread));
    } catch (e) {
      emit(NotificationsError(e.toString()));
    }
  }

  Future<void> _onMarkRead(
    NotificationMarkReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _api.put(ApiEndpoints.notificationMarkRead(event.notificationId), {});
      if (state is NotificationsLoaded) {
        final current = state as NotificationsLoaded;
        final updated = current.notifications.map((n) {
          return n.id == event.notificationId ? n.copyWith(isRead: true) : n;
        }).toList();
        final unread = updated.where((n) => !n.isRead).length;
        emit(current.copyWith(notifications: updated, unreadCount: unread));
      }
    } catch (_) {}
  }

  Future<void> _onMarkAllRead(
    NotificationsMarkAllReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _api.put(ApiEndpoints.notificationsMarkAllRead(event.userId), {});
      if (state is NotificationsLoaded) {
        final current = state as NotificationsLoaded;
        final updated = current.notifications.map((n) => n.copyWith(isRead: true)).toList();
        emit(current.copyWith(notifications: updated, unreadCount: 0));
      }
    } catch (_) {}
  }

  void _onReceived(
    NotificationReceived event,
    Emitter<NotificationState> emit,
  ) {
    if (state is NotificationsLoaded) {
      final current = state as NotificationsLoaded;
      final updated = [event.notification, ...current.notifications];
      final unread = updated.where((n) => !n.isRead).length;
      emit(current.copyWith(notifications: updated, unreadCount: unread));
    } else {
      emit(NotificationsLoaded(
        notifications: [event.notification],
        unreadCount: 1,
      ));
    }
  }

  @override
  Future<void> close() {
    _socketSub?.cancel();
    return super.close();
  }
}
