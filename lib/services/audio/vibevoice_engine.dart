import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'audio_engine.dart';

/// VibeVoice API implementation of AudioEngine
class VibeVoiceEngine extends AudioEngine {
  final Dio _dio;
  final String baseUrl;
  final Connectivity _connectivity;
  bool _isInitialized = false;

  VibeVoiceEngine({
    Dio? dio,
    this.baseUrl = 'http://localhost:5000',
    Connectivity? connectivity,
  })  : _dio = dio ?? Dio(),
        _connectivity = connectivity ?? Connectivity();

  @override
  String get name => 'VibeVoice';

  @override
  bool get requiresNetwork => true;

  @override
  Future<bool> get isAvailable async {
    if (!_isInitialized) return false;
    
    // Check network connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }

    // Check API health
    try {
      final response = await _dio.get(
        '$baseUrl/health',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200 && 
             response.data['status'] == 'ok' &&
             response.data['tts'] == true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    );

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
      throw AudioEngineException('VibeVoice API is not available');
    }

    try {
      final response = await _dio.post(
        '/synthesize',
        data: {
          'text': text,
          'voice': voice ?? 'ja-JP-Standard-A',
          'speed': speed,
          'pitch': pitch,
          'language': language ?? 'ja-JP',
        },
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200) {
        return Uint8List.fromList(response.data);
      } else {
        throw AudioEngineException(
          'Failed to synthesize: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw AudioEngineException('Request timeout');
      } else if (e.response?.statusCode == 429) {
        throw AudioEngineException('Rate limit exceeded');
      } else {
        throw AudioEngineException(
          'Network error: ${e.message}',
        );
      }
    } catch (e) {
      throw AudioEngineException('Unexpected error: $e');
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

    try {
      final response = await _dio.get(
        '/voices',
        queryParameters: language != null ? {'language_code': language} : null,
      );

      if (response.statusCode == 200) {
        final List<dynamic> voicesData = response.data;
        return voicesData.map((voice) {
          return VoiceInfo(
            id: voice['name'],
            name: voice['name'],
            language: voice['language_codes'][0],
            gender: voice['ssml_gender'],
            isDefault: voice['name'] == 'ja-JP-Standard-A',
          );
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> dispose() async {
    _dio.close();
    _isInitialized = false;
  }
}

/// Exception thrown by audio engines
class AudioEngineException implements Exception {
  final String message;
  
  AudioEngineException(this.message);
  
  @override
  String toString() => 'AudioEngineException: $message';
}