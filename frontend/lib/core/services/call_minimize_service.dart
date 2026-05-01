import 'package:flutter/foundation.dart';

/// Tracks whether the active call has been minimized to the floating bar.
/// This is pure UI state — the [CallBloc] session is unaffected.
class CallMinimizeService {
  static final instance = CallMinimizeService._();
  CallMinimizeService._();

  final ValueNotifier<bool> isMinimized = ValueNotifier(false);

  void minimize() => isMinimized.value = true;
  void restore() => isMinimized.value = false;
}
