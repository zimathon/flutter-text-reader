import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:text_reader_app/models/audio_segment.dart';

enum TtsEngine {
  androidNative,
  vibeVoice,
}

class TtsService {
  final FlutterTts _flutterTts;
  bool _isInitialized = false;
  
  TtsService({FlutterTts? flutterTts}) 
      : _flutterTts = flutterTts ?? FlutterTts();
  TtsEngine _currentEngine = TtsEngine.androidNative;
  
  // TTS Settings
  double _speechRate = 1.0;
  double _volume = 1.0;
  double _pitch = 1.0;
  String? _language = 'ja-JP';
  String? _voice;
  
  // Callbacks
  Function(String)? onStart;
  Function()? onComplete;
  Function(String)? onError;
  Function(int, int)? onProgress;
  
  // Queue management
  final List<AudioSegment> _queue = [];
  bool _isProcessing = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _initializeFlutterTts();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing TTS service: $e');
      throw Exception('Failed to initialize TTS service');
    }
  }
  
  Future<void> _initializeFlutterTts() async {
    // Set up handlers
    _flutterTts.setStartHandler(() {
      onStart?.call('');
    });
    
    _flutterTts.setCompletionHandler(() {
      onComplete?.call();
    });
    
    _flutterTts.setErrorHandler((msg) {
      onError?.call(msg.toString());
    });
    
    _flutterTts.setProgressHandler((text, start, end, word) {
      onProgress?.call(start, end);
    });
    
    // Configure TTS settings
    await _flutterTts.setLanguage(_language ?? 'ja-JP');
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setPitch(_pitch);
    
    // Android specific settings
    if (Platform.isAndroid) {
      await _flutterTts.setQueueMode(1); // QUEUE_ADD mode
      await _flutterTts.awaitSpeakCompletion(true);
    }
    
    // Get available languages and voices
    final languages = await _flutterTts.getLanguages;
    print('Available languages: $languages');
    
    final voices = await _flutterTts.getVoices;
    print('Available voices: ${voices.length}');
    
    // Select Japanese voice if available
    final japaneseVoices = voices.where((voice) {
      final locale = voice['locale'] ?? '';
      return locale.toString().toLowerCase().contains('ja');
    }).toList();
    
    if (japaneseVoices.isNotEmpty) {
      final preferredVoice = japaneseVoices.first;
      _voice = preferredVoice['name'];
      await _flutterTts.setVoice({
        'name': preferredVoice['name'],
        'locale': preferredVoice['locale'],
      });
      print('Selected Japanese voice: $_voice');
    }
  }
  
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('TtsService not initialized. Call initialize() first.');
    }
  }
  
  Future<AudioSegment> generateAudioSegment(
    String text, {
    String? segmentId,
    int startPosition = 0,
    int? endPosition,
  }) async {
    _ensureInitialized();
    
    final id = segmentId ?? 'segment_${DateTime.now().millisecondsSinceEpoch}';
    final end = endPosition ?? text.length;
    
    final segment = AudioSegment(
      id: id,
      text: text,
      startPosition: startPosition,
      endPosition: end,
      status: AudioSegmentStatus.pending,
      ttsEngine: _currentEngine == TtsEngine.androidNative 
          ? 'android-native' 
          : 'vibevoice',
    );
    
    try {
      // For Android native TTS, we'll use direct synthesis
      if (_currentEngine == TtsEngine.androidNative) {
        return await _generateWithAndroidTts(segment);
      } else {
        // VibeVoice will be implemented in Task 6
        throw UnimplementedError('VibeVoice not yet implemented');
      }
    } catch (e) {
      return segment.copyWith(
        status: AudioSegmentStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
  
  Future<AudioSegment> _generateWithAndroidTts(AudioSegment segment) async {
    try {
      final updatedSegment = segment.copyWith(
        status: AudioSegmentStatus.generating,
      );
      
      // For Android native TTS, we'll synthesize to file
      final tempDir = await getTemporaryDirectory();
      final audioFilePath = '${tempDir.path}/tts_${segment.id}.wav';
      
      // Synthesize to file
      final result = await _flutterTts.synthesizeToFile(
        segment.text,
        audioFilePath,
      );
      
      if (result == 1) {
        // Success
        final audioFile = File(audioFilePath);
        if (await audioFile.exists()) {
          final audioData = await audioFile.readAsBytes();
          
          return updatedSegment.copyWith(
            status: AudioSegmentStatus.ready,
            audioFilePath: audioFilePath,
            audioData: audioData,
            generatedAt: DateTime.now(),
          );
        }
      }
      
      throw Exception('Failed to synthesize audio');
    } catch (e) {
      return segment.copyWith(
        status: AudioSegmentStatus.error,
        errorMessage: 'Android TTS error: $e',
      );
    }
  }
  
  Future<void> speak(String text) async {
    _ensureInitialized();
    
    if (text.isEmpty) return;
    
    try {
      await stop(); // Stop any ongoing speech
      final result = await _flutterTts.speak(text);
      if (result != 1) {
        throw Exception('TTS speak failed with result: $result');
      }
    } catch (e) {
      onError?.call('Speak error: $e');
      rethrow;
    }
  }
  
  Future<void> speakSegment(AudioSegment segment) async {
    _ensureInitialized();
    
    if (segment.status != AudioSegmentStatus.ready) {
      throw StateError('Segment is not ready for playback');
    }
    
    await speak(segment.text);
  }
  
  Future<void> pause() async {
    _ensureInitialized();
    
    try {
      final result = await _flutterTts.pause();
      if (result != 1) {
        throw Exception('TTS pause failed');
      }
    } catch (e) {
      onError?.call('Pause error: $e');
      rethrow;
    }
  }
  
  Future<void> stop() async {
    _ensureInitialized();
    
    try {
      final result = await _flutterTts.stop();
      if (result != 1) {
        print('TTS stop returned: $result');
      }
    } catch (e) {
      onError?.call('Stop error: $e');
      rethrow;
    }
  }
  
  Future<void> setSpeechRate(double rate) async {
    _ensureInitialized();
    
    _speechRate = rate.clamp(0.1, 3.0);
    await _flutterTts.setSpeechRate(_speechRate);
  }
  
  Future<void> setVolume(double volume) async {
    _ensureInitialized();
    
    _volume = volume.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_volume);
  }
  
  Future<void> setPitch(double pitch) async {
    _ensureInitialized();
    
    _pitch = pitch.clamp(0.5, 2.0);
    await _flutterTts.setPitch(_pitch);
  }
  
  Future<void> setLanguage(String languageCode) async {
    _ensureInitialized();
    
    _language = languageCode;
    await _flutterTts.setLanguage(languageCode);
  }
  
  Future<void> setVoice(Map<String, String> voice) async {
    _ensureInitialized();
    
    _voice = voice['name'];
    await _flutterTts.setVoice(voice);
  }
  
  Future<List<dynamic>> getAvailableLanguages() async {
    _ensureInitialized();
    return await _flutterTts.getLanguages;
  }
  
  Future<List<dynamic>> getAvailableVoices() async {
    _ensureInitialized();
    return await _flutterTts.getVoices;
  }
  
  Future<Map<String, dynamic>> getCurrentVoice() async {
    _ensureInitialized();
    
    return {
      'language': _language,
      'voice': _voice,
      'speechRate': _speechRate,
      'volume': _volume,
      'pitch': _pitch,
      'engine': _currentEngine.toString(),
    };
  }
  
  void switchEngine(TtsEngine engine) {
    _currentEngine = engine;
  }
  
  TtsEngine get currentEngine => _currentEngine;
  
  bool get isInitialized => _isInitialized;
  
  double get speechRate => _speechRate;
  double get volume => _volume;
  double get pitch => _pitch;
  String? get language => _language;
  
  // Queue management for batch processing
  void addToQueue(AudioSegment segment) {
    _queue.add(segment);
  }
  
  void clearQueue() {
    _queue.clear();
    _isProcessing = false;
  }
  
  Future<void> processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    
    _isProcessing = true;
    
    try {
      while (_queue.isNotEmpty) {
        final segment = _queue.removeAt(0);
        
        // Generate audio if not ready
        AudioSegment processedSegment = segment;
        if (segment.status != AudioSegmentStatus.ready) {
          processedSegment = await generateAudioSegment(
            segment.text,
            segmentId: segment.id,
            startPosition: segment.startPosition,
            endPosition: segment.endPosition,
          );
        }
        
        // Speak the segment if ready
        if (processedSegment.status == AudioSegmentStatus.ready) {
          await speakSegment(processedSegment);
          
          // Wait for completion
          final completer = Completer<void>();
          Function()? originalComplete = onComplete;
          onComplete = () {
            originalComplete?.call();
            completer.complete();
          };
          
          await completer.future;
          onComplete = originalComplete;
        }
      }
    } finally {
      _isProcessing = false;
    }
  }
  
  bool get isProcessingQueue => _isProcessing;
  int get queueLength => _queue.length;
  
  Future<void> dispose() async {
    await stop();
    clearQueue();
    _isInitialized = false;
  }
}