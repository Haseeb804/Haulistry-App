import 'package:flutter/widgets.dart';

import 'realtime_socket_service.dart';

class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._();
  AppLifecycleService._();
  factory AppLifecycleService() => _instance;

  void initialize() {
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
    }
  }
}
