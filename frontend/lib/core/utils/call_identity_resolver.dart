import '../constants/app_constants.dart';
import '../services/api_service.dart';

class CallParticipantIdentity {
  final String userId;
  final String displayName;
  final String role;
  final String? profileImageUrl;

  const CallParticipantIdentity({
    required this.userId,
    required this.displayName,
    required this.role,
    this.profileImageUrl,
  });

  CallParticipantIdentity copyWith({
    String? userId,
    String? displayName,
    String? role,
    String? profileImageUrl,
  }) {
    return CallParticipantIdentity(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}

class CallIdentityResolver {
  static final Map<String, Future<CallParticipantIdentity>> _identityCache = {};

  static const Set<String> _genericLabels = {
    'provider',
    'seeker',
    'user',
    'voice call',
    'video call',
    'calling...',
    'connecting...',
    'connecting video call...',
    'incoming call',
    'waiting for other person...',
    'waiting for other person',
    'service',
  };

  static bool _looksLikeGeneratedId(String value) {
    final normalized = value.trim();
    if (normalized.length < 16) return false;
    if (normalized.contains(RegExp(r'\s'))) return false;

    final idShape = RegExp(r'^[A-Za-z0-9_-]+$');
    if (!idShape.hasMatch(normalized)) return false;

    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(normalized);
    final hasDigit = RegExp(r'\d').hasMatch(normalized);
    return hasLetter && hasDigit;
  }

  static bool isGenericDisplayName(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return true;
    return _genericLabels.contains(normalized) || _looksLikeGeneratedId(normalized);
  }

  static String resolveDisplayName({
    String? preferredName,
    String? fallbackName,
    required String defaultLabel,
  }) {
    if (!isGenericDisplayName(preferredName)) {
      return preferredName!.trim();
    }
    if (!isGenericDisplayName(fallbackName)) {
      return fallbackName!.trim();
    }
    return defaultLabel;
  }

  static String resolveRole({
    String? preferredRole,
    String? fallbackRole,
    String defaultRole = AppConstants.roleUser,
  }) {
    final preferred = preferredRole?.trim() ?? '';
    if (preferred.isNotEmpty && preferred.toLowerCase() != AppConstants.roleUser) {
      return preferred;
    }

    final fallback = fallbackRole?.trim() ?? '';
    if (fallback.isNotEmpty && fallback.toLowerCase() != AppConstants.roleUser) {
      return fallback;
    }

    return defaultRole;
  }

  static String? resolveProfileImageUrl({
    String? preferredImageUrl,
    String? fallbackImageUrl,
  }) {
    final preferred = preferredImageUrl?.trim() ?? '';
    if (preferred.isNotEmpty) return preferred;

    final fallback = fallbackImageUrl?.trim() ?? '';
    if (fallback.isNotEmpty) return fallback;

    return null;
  }

  static Future<CallParticipantIdentity> resolveParticipant({
    required String userId,
    String? fallbackName,
    String? fallbackRole,
    String? fallbackProfileImageUrl,
    String defaultLabel = 'User',
  }) {
    final trimmedUserId = userId.trim();
    final fallbackNameIsGeneric = isGenericDisplayName(fallbackName);
    final fallbackImageMissing = (fallbackProfileImageUrl?.trim() ?? '').isEmpty;

    if (trimmedUserId.isEmpty || (!fallbackNameIsGeneric && !fallbackImageMissing)) {
      return Future.value(
        CallParticipantIdentity(
          userId: trimmedUserId,
          displayName: resolveDisplayName(
            preferredName: fallbackName,
            fallbackName: fallbackName,
            defaultLabel: defaultLabel,
          ),
          role: resolveRole(
            preferredRole: fallbackRole,
            fallbackRole: fallbackRole,
          ),
          profileImageUrl: resolveProfileImageUrl(
            preferredImageUrl: fallbackProfileImageUrl,
          ),
        ),
      );
    }

    return _identityCache.putIfAbsent(trimmedUserId, () async {
      String? fetchedName;
      String? fetchedRole;
      String? fetchedImageUrl;

      try {
        final response = await ApiService.instance.get('/auth/user/$trimmedUserId');
        if (response['success'] == true && response['user'] is Map<String, dynamic>) {
          final user = response['user'] as Map<String, dynamic>;
          fetchedName = (user['name'] ?? user['fullName'] ?? user['displayName'])?.toString();
          fetchedRole = (user['role'] ?? user['userRole'])?.toString();
          fetchedImageUrl = (user['profileImageUrl'] ?? user['profile_image_url'])?.toString();
        }
      } catch (_) {
        // Best effort; fall back to supplied values.
      }

      return CallParticipantIdentity(
        userId: trimmedUserId,
        displayName: resolveDisplayName(
          preferredName: fetchedName,
          fallbackName: fallbackName,
          defaultLabel: defaultLabel,
        ),
        role: resolveRole(
          preferredRole: fetchedRole,
          fallbackRole: fallbackRole,
        ),
        profileImageUrl: resolveProfileImageUrl(
          preferredImageUrl: fetchedImageUrl,
          fallbackImageUrl: fallbackProfileImageUrl,
        ),
      );
    });
  }
}
