import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:text_reader_app/models/audio_segment.dart';
import 'package:text_reader_app/services/api_client.dart';
import 'package:text_reader_app/services/storage_service.dart';

class VibeVoiceService {
  final ApiClient _apiClient;
  final StorageService _storageService;
  bool _isAvailable = false;
  String? _currentVoice;
  List<String> _availableVoices = [];
  
  // Cache management
  final Map<String, Uint8List> _audioCache = {};
  static const int _maxCacheSize = 50; // Maximum cached segments
  
  VibeVoiceService({
    ApiClient? apiClient,
    StorageService? storageService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storageService = storageService ?? StorageService();
  
  Future<void> initialize() async {
    try {
      await _storageService.initialize();
      
      // Load API URL from settings
      final apiUrl = await _storageService.getVibeVoiceApiUrl();
      if (apiUrl != null && apiUrl.isNotEmpty) {
        _apiClient.updateBaseUrl(apiUrl);
      }
      
      // Check connection and get available voices
      await checkAvailability();
      
      if (_isAvailable) {
        await _loadAvailableVoices();
      }
    } catch (e) {
      print('Error initializing VibeVoice service: $e');
      _isAvailable = false;
    }
  }
  
  Future<bool> checkAvailability() async {
    try {
      _isAvailable = await _apiClient.checkConnection();
      return _isAvailable;
    } catch (e) {
      print('VibeVoice availability check failed: $e');
      _isAvailable = false;
      return false;
    }
  }
  
  Future<void> _loadAvailableVoices() async {
    try {
      _availableVoices = await _apiClient.getAvailableVoices();
      
      // Select default voice (preferably Japanese)
      if (_availableVoices.isNotEmpty) {
        _currentVoice = _availableVoices.firstWhere(
          (voice) => voice.toLowerCase().contains('ja') || 
                     voice.toLowerCase().contains('japanese'),
          orElse: () => _availableVoices.first,
        );
      }
      
      print('VibeVoice voices loaded: $_availableVoices');
      print('Selected voice: $_currentVoice');
    } catch (e) {
      print('Failed to load VibeVoice voices: $e');
    }
  }
  
  Future<AudioSegment> generateAudioSegment(
    AudioSegment segment, {
    double? speed,
    double? pitch,
    bool useCache = true,
  }) async {
    if (!_isAvailable) {
      return segment.copyWith(
        status: AudioSegmentStatus.error,
        errorMessage: 'VibeVoice service is not available',
      );
    }
    
    try {
      // Check cache first
      final cacheKey = _generateCacheKey(segment.text, speed, pitch);
      if (useCache && _audioCache.containsKey(cacheKey)) {
        print('Using cached audio for segment ${segment.id}');
        return await _createSegmentFromCache(segment, cacheKey);
      }
      
      // Update status to generating
      final generatingSegment = segment.copyWith(
        status: AudioSegmentStatus.generating,
      );
      
      // Call VibeVoice API
      final audioData = await _apiClient.synthesizeSpeech(
        text: segment.text,
        voice: _currentVoice,
        speed: speed,
        pitch: pitch,
        language: 'ja-JP',
      );
      
      if (audioData == null || audioData.isEmpty) {
        throw Exception('No audio data received from VibeVoice');
      }
      
      // Save to cache
      if (useCache) {
        _addToCache(cacheKey, audioData);
      }
      
      // Save to file
      final audioPath = await _saveAudioToFile(segment.id, audioData);
      
      return generatingSegment.copyWith(
        status: AudioSegmentStatus.ready,
        audioData: audioData,
        audioFilePath: audioPath,
        generatedAt: DateTime.now(),
        ttsEngine: 'vibevoice',
      );
    } on ApiException catch (e) {
      return segment.copyWith(
        status: AudioSegmentStatus.error,
        errorMessage: 'VibeVoice API error: ${e.message}',
      );
    } catch (e) {
      return segment.copyWith(
        status: AudioSegmentStatus.error,
        errorMessage: 'VibeVoice generation failed: $e',
      );
    }
  }
  
  Future<List<AudioSegment>> generateBatch(
    List<AudioSegment> segments, {
    double? speed,
    double? pitch,
    Function(int, int)? onProgress,
  }) async {
    final results = <AudioSegment>[];
    
    for (int i = 0; i < segments.length; i++) {
      onProgress?.call(i + 1, segments.length);
      
      final result = await generateAudioSegment(
        segments[i],
        speed: speed,
        pitch: pitch,
      );
      
      results.add(result);
      
      // Add small delay between requests to avoid overwhelming the server
      if (i < segments.length - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    return results;
  }
  
  String _generateCacheKey(String text, double? speed, double? pitch) {
    final speedStr = speed?.toStringAsFixed(2) ?? '1.00';
    final pitchStr = pitch?.toStringAsFixed(2) ?? '1.00';
    final voiceStr = _currentVoice ?? 'default';
    final textHash = text.hashCode.toString();
    return '${voiceStr}_${speedStr}_${pitchStr}_$textHash';
  }
  
  void _addToCache(String key, Uint8List data) {
    // Implement LRU cache
    if (_audioCache.length >= _maxCacheSize) {
      // Remove oldest entry (first in map)
      final oldestKey = _audioCache.keys.first;
      _audioCache.remove(oldestKey);
    }
    
    _audioCache[key] = data;
  }
  
  Future<AudioSegment> _createSegmentFromCache(
    AudioSegment segment,
    String cacheKey,
  ) async {
    final audioData = _audioCache[cacheKey]!;
    final audioPath = await _saveAudioToFile(segment.id, audioData);
    
    return segment.copyWith(
      status: AudioSegmentStatus.ready,
      audioData: audioData,
      audioFilePath: audioPath,
      generatedAt: DateTime.now(),
      ttsEngine: 'vibevoice',
    );
  }
  
  Future<String> _saveAudioToFile(String segmentId, Uint8List audioData) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final audioDir = Directory('${tempDir.path}/vibevoice_audio');
      
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      
      final audioFile = File('${audioDir.path}/$segmentId.wav');
      await audioFile.writeAsBytes(audioData);
      
      return audioFile.path;
    } catch (e) {
      print('Failed to save audio file: $e');
      throw Exception('Failed to save audio file');
    }
  }
  
  Future<void> updateApiUrl(String newUrl) async {
    _apiClient.updateBaseUrl(newUrl);
    await _storageService.setVibeVoiceApiUrl(newUrl);
    
    // Re-check availability with new URL
    await checkAvailability();
    if (_isAvailable) {
      await _loadAvailableVoices();
    }
  }
  
  void setVoice(String voice) {
    if (_availableVoices.contains(voice)) {
      _currentVoice = voice;
    }
  }
  
  void clearCache() {
    _audioCache.clear();
  }
  
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final audioDir = Directory('${tempDir.path}/vibevoice_audio');
      
      if (await audioDir.exists()) {
        await audioDir.delete(recursive: true);
      }
    } catch (e) {
      print('Failed to cleanup temp files: $e');
    }
  }
  
  Map<String, dynamic> getStatus() {
    return {
      'available': _isAvailable,
      'apiUrl': _apiClient.baseUrl,
      'currentVoice': _currentVoice,
      'availableVoices': _availableVoices,
      'cacheSize': _audioCache.length,
    };
  }
  
  bool get isAvailable => _isAvailable;
  String? get currentVoice => _currentVoice;
  List<String> get availableVoices => _availableVoices;
  int get cacheSize => _audioCache.length;
  
  void dispose() {
    _apiClient.dispose();
    clearCache();
  }
}