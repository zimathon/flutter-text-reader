import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_engine.dart';

/// Android TTS implementation of AudioEngine
class AndroidTtsEngine extends AudioEngine {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  List<Map<String, String>> _voices = [];

  @override
  String get name => 'Android TTS';

  @override
  bool get requiresNetwork => false;

  @override
  Future<bool> get isAvailable async {
    if (!Platform.isAndroid) return false;
    
    try {
      final engines = await _flutterTts.getEngines;
      return engines != null && engines.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!Platform.isAndroid) {
      throw AudioEngineException('Android TTS is only available on Android');
    }

    // Configure TTS settings
    await _flutterTts.setSharedInstance(true);
    await _flutterTts.awaitSpeakCompletion(true);
    
    // Load available voices
    final dynamic voices = await _flutterTts.getVoices;
    if (voices != null && voices is List) {
      _voices = voices.map((voice) {
        return Map<String, String>.from(voice as Map);
      }).toList();
    }

    _isInitialized = true;
  }

  @override
  Future<Uint8List> synthesize({
    required String text,
    String? voice,
    double speed = 1.0,
    double pitch = 1.0,
    String? language,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!await isAvailable) {
      throw AudioEngineException('Android TTS is not available');
    }

    try {
      // Set language
      final lang = language ?? 'ja-JP';
      await _flutterTts.setLanguage(lang);

      // Set voice if specified
      if (voice != null) {
        final voiceMap = _voices.firstWhere(
          (v) => v['name'] == voice,
          orElse: () => <String, String>{},
        );
        if (voiceMap.isNotEmpty) {
          await _flutterTts.setVoice(voiceMap);
        }
      }

      // Set speech rate and pitch
      await _flutterTts.setSpeechRate(speed);
      await _flutterTts.setPitch(pitch);

      // Synthesize to file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'tts_$timestamp.wav';
      final filePath = '${tempDir.path}/$fileName';

      // Use synthesizeToFile for offline synthesis
      final result = await _flutterTts.synthesizeToFile(text, fileName);
      
      if (result == 1) {
        // Read the file and return as bytes
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          
          // Clean up temp file
          await file.delete();
          
          return bytes;
        } else {
          throw AudioEngineException('Failed to generate audio file');
        }
      } else {
        throw AudioEngineException('TTS synthesis failed');
      }
    } catch (e) {
      if (e is AudioEngineException) rethrow;
      throw AudioEngineException('Android TTS error: $e');
    }
  }

  @override
  Future<List<VoiceInfo>> getAvailableVoices({String? language}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!await isAvailable) {
      return [];
    }

    return _voices
        .where((voice) => 
            language == null || 
            voice['locale']?.startsWith(language.split('-')[0]) == true)
        .map((voice) {
          return VoiceInfo(
            id: voice['name'] ?? '',
            name: voice['name'] ?? '',
            language: voice['locale'] ?? '',
            gender: null, // Android TTS doesn't provide gender info
            isDefault: voice['locale'] == 'ja-JP',
          );
        }).toList();
  }

  @override
  Future<void> dispose() async {
    await _flutterTts.stop();
    _isInitialized = false;
  }

  /// Utility method to directly speak text (for testing)
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    await _flutterTts.speak(text);
  }

  /// Stop current speech
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}