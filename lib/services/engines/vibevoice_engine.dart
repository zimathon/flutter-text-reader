import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'speech_engine.dart';
import '../../models/audio_chunk.dart';
import '../../models/speech_config.dart';

/// VibeVoice API implementation of SpeechEngine
class VibeVoiceEngine extends BaseSpeechEngine {
  static const String defaultApiUrl = 'http://localhost:5000';
  static const int defaultMaxTextLength = 5000;
  static const Duration requestTimeout = Duration(seconds: 30);

  final String apiUrl;
  final http.Client _httpClient;
  
  VibeVoiceEngine({
    String? apiUrl,
    http.Client? httpClient,
  })  : apiUrl = apiUrl ?? defaultApiUrl,
        _httpClient = httpClient ?? http.Client();

  @override
  bool get isOffline => false;

  @override
  bool get supportsStreaming => false; // Will be true when SSE is implemented

  @override
  int get maxTextLength => defaultMaxTextLength;

  @override
  Future<void> initialize() async {
    try {
      status = EngineStatus.initializing;
      
      // Check API health
      final isAvailable = await checkAvailability();
      if (!isAvailable) {
        throw Exception('VibeVoice API is not available');
      }
      
      status = EngineStatus.ready;
      debugPrint('VibeVoiceEngine: Initialized successfully');
    } catch (e) {
      status = EngineStatus.error;
      debugPrint('VibeVoiceEngine: Initialization failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    status = EngineStatus.disposed;
    _httpClient.close();
    debugPrint('VibeVoiceEngine: Disposed');
  }

  @override
  Future<bool> checkAvailability() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$apiUrl/health'))
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'ok' || data['status'] == 'degraded';
      }
      return false;
    } catch (e) {
      debugPrint('VibeVoiceEngine: Health check failed: $e');
      return false;
    }
  }

  @override
  Future<List<VoiceInfo>> getAvailableVoices() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$apiUrl/voices'))
          .timeout(requestTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final voices = data['voices'] as List;
        
        return voices.map((voice) => VoiceInfo(
          id: voice['id'],
          name: voice['name'],
          languageCode: voice['language_code'],
          gender: voice['ssml_gender'],
          isOnline: true,
        )).toList();
      }
      return [];
    } catch (e) {
      debugPrint('VibeVoiceEngine: Failed to get voices: $e');
      return [];
    }
  }

  @override
  Stream<AudioChunk> synthesize(
    String text, {
    SpeechConfig? config,
    CancellationToken? cancellationToken,
  }) {
    // Create a stream controller
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

      // Prepare request body
      final requestBody = {
        'text': text,
        'voice': config.voice ?? 'ja-JP-Standard-A',
        'speed': config.speed,
        'pitch': config.pitch,
        'language': config.language,
        'volume_gain_db': config.volumeGainDb,
      };

      // Make API request
      final response = await _httpClient
          .post(
            Uri.parse('$apiUrl/synthesize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(requestTimeout);

      // Check cancellation again
      if (cancellationToken?.isCancelled ?? false) {
        await controller.close();
        return;
      }

      if (response.statusCode == 200) {
        // Success - emit audio chunk
        final audioData = response.bodyBytes;
        controller.add(AudioChunk(
          data: Uint8List.fromList(audioData),
          sequenceNumber: 0,
          isLast: true,
        ));
        
        debugPrint('VibeVoiceEngine: Synthesized ${text.length} characters');
      } else {
        // API error
        String errorMessage = 'API error: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {}
        
        controller.addError(Exception(errorMessage));
      }
    } catch (e) {
      // Handle any errors
      debugPrint('VibeVoiceEngine: Synthesis error: $e');
      controller.addError(e);
    } finally {
      // Clean up
      status = EngineStatus.ready;
      await controller.close();
    }
  }

  /// Create engine with custom configuration
  factory VibeVoiceEngine.withConfig({
    required String apiUrl,
    http.Client? httpClient,
  }) {
    return VibeVoiceEngine(
      apiUrl: apiUrl,
      httpClient: httpClient,
    );
  }
}