class AgoraConfig {
  /// Agora App ID from Agora Console
  /// Get your free Agora App ID at: https://console.agora.io
  static const String appId = 'f273db33344f45e9b8850443c0b5385e';
  
  /// Enable/disable Agora logs for debugging
  static const bool enableLogs = true;
  
  /// Token expiration time in seconds (24 hours)
  static const int tokenExpirationTime = 86400;
  
  /// Default channel profile
  static const int channelProfileCommunication = 0;
  static const int channelProfileLiveBroadcasting = 1;
  
  /// Audio profile settings
  static const int audioProfileDefault = 0;
  static const int audioProfileSpeechStandard = 1;
  static const int audioProfileMusicStandard = 2;
  static const int audioProfileMusicStandardStereo = 3;
  static const int audioProfileMusicHighQuality = 4;
  static const int audioProfileMusicHighQualityStereo = 5;
  
  /// Video encoder configuration
  static const videoDimension640x360 = {
    'width': 640,
    'height': 360,
  };
  
  static const videoDimension1280x720 = {
    'width': 1280,
    'height': 720,
  };
  
  /// Validate if App ID is configured
  static bool get isConfigured => appId != 'YOUR_AGORA_APP_ID' && appId.isNotEmpty;
  
  /// Get error message if not configured
  static String get configurationError => 
      'Agora App ID not configured. Please add your App ID in agora_config.dart';
}
