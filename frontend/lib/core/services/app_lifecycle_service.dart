import 'dart:async';
import 'package:flutter/widgets.dart';

import 'realtime_socket_service.dart';

class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._();
  AppLifecycleService._();
  factory AppLifecycleService() => _instance;

  Future<void> Function()? _onResumed;

  void initialize({Future<void> Function()? onResumed}) {
    _onResumed = onResumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect socket after app returns from background.
      // connect() is idempotent — safe to call when already connected.
      RealtimeSocketService().connect();
      final callback = _onResumed;
      if (callback != null) {
        unawaited(callback());
      }
    }
  }
}
