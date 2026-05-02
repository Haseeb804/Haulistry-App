import 'package:flutter/foundation.dart';

/// Tracks whether the active call has been minimized to the floating bar.
/// Stores enough identity to restore the call screen without reading BLoC state.
/// This is pure UI state — the [CallBloc] session is unaffected.
class CallMinimizeService {
  static final instance = CallMinimizeService._();
  CallMinimizeService._();

  final ValueNotifier<bool> isMinimized = ValueNotifier(false);

  // Call identity stored when minimize() is called so restore can read it
  // synchronously without depending on BLoC state timing.
  String callId = '';
  String callType = '';
  String otherUserName = '';
  String otherUserRole = '';
  String? otherUserProfileImageUrl;

  void minimize({
    required String callId,
    required String callType,
    required String otherUserName,
    required String otherUserRole,
    String? otherUserProfileImageUrl,
  }) {
    this.callId = callId;
    this.callType = callType;
    this.otherUserName = otherUserName;
    this.otherUserRole = otherUserRole;
    this.otherUserProfileImageUrl = otherUserProfileImageUrl;
    isMinimized.value = true;
  }

  void restore() => isMinimized.value = false;

  void clear() {
    isMinimized.value = false;
    callId = '';
    callType = '';
    otherUserName = '';
    otherUserRole = '';
    otherUserProfileImageUrl = null;
  }
}
