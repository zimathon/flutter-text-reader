import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'speech_engine.dart';
import '../../models/audio_chunk.dart';
import '../../models/speech_config.dart';

/// Android TTS implementation of SpeechEngine
class AndroidTtsEngine extends BaseSpeechEngine {
  static const int defaultMaxTextLength = 4000;
  static const int chunkSize = 500; // Characters per chunk for TTS

  final FlutterTts _flutterTts;
  final StreamController<AudioChunk> _audioStreamController = 
      StreamController<AudioChunk>.broadcast();
  
  int _currentSequence = 0;
  CancellationToken? _currentCancellationToken;
  
  AndroidTtsEngine({FlutterTts? flutterTts})
      : _flutterTts = flutterTts ?? FlutterTts();

  @override
  bool get isOffline => true;

  @override
  bool get supportsStreaming => true;

  @override
  int get maxTextLength => defaultMaxTextLength;

  @override
  Future<void> initialize() async {
    try {
      status = EngineStatus.initializing;
      
      // Configure TTS settings
      await _flutterTts.setLanguage('ja-JP');
      await _flutterTts.setSpeechRate(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      
      // Set up callbacks
      _flutterTts.setStartHandler(() {
        debugPrint('AndroidTtsEngine: Speech started');
      });
      
      _flutterTts.setCompletionHandler(() {
        debugPrint('AndroidTtsEngine: Speech completed');
      });
      
      _flutterTts.setErrorHandler((error) {
        debugPrint('AndroidTtsEngine: Error: $error');
        _audioStreamController.addError(error);
      });
      
      _flutterTts.setCancelHandler(() {
        debugPrint('AndroidTtsEngine: Speech cancelled');
      });
      
      // Check if TTS is available
      final isAvailable = await checkAvailability();
      if (!isAvailable) {
        throw Exception('Android TTS is not available');
      }
      
      status = EngineStatus.ready;
      debugPrint('AndroidTtsEngine: Initialized successfully');
    } catch (e) {
      status = EngineStatus.error;
      debugPrint('AndroidTtsEngine: Initialization failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    await _flutterTts.stop();
    await _audioStreamController.close();
    status = EngineStatus.disposed;
    debugPrint('AndroidTtsEngine: Disposed');
  }

  @override
  Future<bool> checkAvailability() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return languages != null && languages.isNotEmpty;
    } catch (e) {
      debugPrint('AndroidTtsEngine: Availability check failed: $e');
      return false;
    }
  }

  @override
  Future<List<VoiceInfo>> getAvailableVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices == null) return [];
      
      final voiceList = <VoiceInfo>[];
      
      for (final voice in voices) {
        if (voice is Map) {
          final name = voice['name']?.toString() ?? 'Unknown';
          final locale = voice['locale']?.toString() ?? 'unknown';
          
          // Filter for Japanese and English voices
          if (locale.startsWith('ja') || locale.startsWith('en')) {
            voiceList.add(VoiceInfo(
              id: name,
              name: name,
              languageCode: locale,
              gender: _inferGender(name),
              isOnline: false,
            ));
          }
        }
      }
      
      return voiceList;
    } catch (e) {
      debugPrint('AndroidTtsEngine: Failed to get voices: $e');
      return [];
    }
  }

  String _inferGender(String voiceName) {
    final lowerName = voiceName.toLowerCase();
    if (lowerName.contains('female') || lowerName.contains('woman')) {
      return 'FEMALE';
    } else if (lowerName.contains('male') || lowerName.contains('man')) {
      return 'MALE';
    }
    return 'NEUTRAL';
  }

  @override
  Stream<AudioChunk> synthesize(
    String text, {
    SpeechConfig? config,
    CancellationToken? cancellationToken,
  }) {
    // Reset sequence counter
    _currentSequence = 0;
    _currentCancellationToken = cancellationToken;
    
    // Create a new stream controller for this synthesis
    final controller = StreamController<AudioChunk>();
    
    // Start synthesis in background
    _performSynthesis(
      text,
      config ?? SpeechConfig.japanese,
      controller,
      cancellationToken,
    );
    
    // Return the stream with cancellation handling
    return handleCancellation(controller.stream, cancellationToken);
  }

  Future<void> _performSynthesis(
    String text,
    SpeechConfig config,
    StreamController<AudioChunk> controller,
    CancellationToken? cancellationToken,
  ) async {
    try {
      // Validate text
      if (!validateText(text)) {
        controller.addError(ArgumentError('Invalid text for synthesis'));
        await controller.close();
        return;
      }

      // Check cancellation
      if (cancellationToken?.isCancelled ?? false) {
        await controller.close();
        return;
      }

      status = EngineStatus.busy;

      // Apply configuration
      await _applyConfig(config);

      // Split text into chunks for better streaming experience
      final chunks = _splitTextIntoChunks(text);
      
      for (int i = 0; i < chunks.length; i++) {
        // Check cancellation before each chunk
        if (cancellationToken?.isCancelled ?? false) {
          await _flutterTts.stop();
          break;
        }

        final chunk = chunks[i];
        final isLastChunk = i == chunks.length - 1;
        
        // Synthesize chunk
        await _synthesizeChunk(
          chunk,
          controller,
          isLastChunk,
          cancellationToken,
        );
      }
      
      debugPrint('AndroidTtsEngine: Completed synthesis of ${text.length} characters');
    } catch (e) {
      debugPrint('AndroidTtsEngine: Synthesis error: $e');
      controller.addError(e);
    } finally {
      status = EngineStatus.ready;
      await controller.close();
    }
  }

  Future<void> _applyConfig(SpeechConfig config) async {
    // Set language
    await _flutterTts.setLanguage(config.language);
    
    // Set speed (TTS uses 0.0-1.0 range, config uses 0.25-4.0)
    final speed = (config.speed - 0.25) / 3.75;
    await _flutterTts.setSpeechRate(speed.clamp(0.0, 1.0));
    
    // Set pitch (TTS uses 0.5-2.0 range, config uses 0.5-2.0)
    await _flutterTts.setPitch(config.pitch.clamp(0.5, 2.0));
    
    // Set volume (convert from dB to linear scale)
    final volume = _dbToLinear(config.volumeGainDb).clamp(0.0, 1.0);
    await _flutterTts.setVolume(volume);
    
    // Set voice if specified
    if (config.voice != null) {
      try {
        await _flutterTts.setVoice({
          'name': config.voice,
          'locale': config.language,
        });
      } catch (e) {
        debugPrint('AndroidTtsEngine: Failed to set voice: $e');
      }
    }
  }

  double _dbToLinear(double db) {
    // Convert dB to linear scale (simplified)
    return 1.0 * (db / 20.0 + 1.0);
  }

  List<String> _splitTextIntoChunks(String text) {
    final chunks = <String>[];
    
    // Split by sentences first
    final sentences = text.split(RegExp(r'[。！？\.\!\?]+'));
    
    String currentChunk = '';
    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) continue;
      
      // Add sentence delimiter back
      final fullSentence = sentence + '。';
      
      if (currentChunk.length + fullSentence.length <= chunkSize) {
        currentChunk += fullSentence;
      } else {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk);
        }
        currentChunk = fullSentence;
      }
    }
    
    // Add remaining chunk
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }
    
    // If no chunks created, split by fixed size
    if (chunks.isEmpty && text.isNotEmpty) {
      for (int i = 0; i < text.length; i += chunkSize) {
        final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
        chunks.add(text.substring(i, end));
      }
    }
    
    return chunks;
  }

  Future<void> _synthesizeChunk(
    String text,
    StreamController<AudioChunk> controller,
    bool isLast,
    CancellationToken? cancellationToken,
  ) async {
    try {
      // Speak the text
      final result = await _flutterTts.speak(text);
      
      if (result == 1) {
        // Success - emit a placeholder audio chunk
        // Note: Android TTS doesn't provide raw audio data
        // This is a placeholder for the streaming interface
        controller.add(AudioChunk(
          data: Uint8List.fromList(utf8.encode(text)), // Placeholder data
          sequenceNumber: _currentSequence++,
          isLast: isLast,
        ));
        
        // Wait for completion (simplified - in production, use proper callbacks)
        if (!isLast) {
          await Future.delayed(Duration(
            milliseconds: (text.length * 100).clamp(500, 3000).toInt(),
          ));
        }
      }
    } catch (e) {
      debugPrint('AndroidTtsEngine: Chunk synthesis error: $e');
      throw e;
    }
  }
}