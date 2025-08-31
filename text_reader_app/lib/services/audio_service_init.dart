import 'package:audio_service/audio_service.dart';
import 'package:text_reader_app/services/audio_service.dart';
import 'package:text_reader_app/services/tts_service.dart';

class AudioServiceInit {
  static AudioPlaybackService? _audioHandler;
  
  static Future<AudioPlaybackService> initialize({
    TtsService? ttsService,
  }) async {
    if (_audioHandler != null) {
      return _audioHandler!;
    }
    
    _audioHandler = await AudioService.init(
      builder: () => AudioPlaybackService(ttsService: ttsService),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.text_reader_app.audio',
        androidNotificationChannelName: 'Text Reader Audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidShowNotificationBadge: false,
        androidNotificationIcon: 'drawable/ic_notification',
        fastForwardInterval: Duration(seconds: 30),
        rewindInterval: Duration(seconds: 30),
      ),
    );
    
    return _audioHandler!;
  }
  
  static AudioPlaybackService? get audioHandler => _audioHandler;
  
  static bool get isInitialized => _audioHandler != null;
  
  static Future<void> dispose() async {
    if (_audioHandler != null) {
      await _audioHandler!.dispose();
      _audioHandler = null;
    }
  }
}