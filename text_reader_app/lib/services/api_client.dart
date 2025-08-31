import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class ApiClient {
  late final Dio _dio;
  String _baseUrl;
  
  ApiClient({String? baseUrl}) 
      : _baseUrl = baseUrl ?? 'http://localhost:5000' {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
      responseType: ResponseType.bytes, // For audio data
    ));
    
    // Add interceptors for logging and error handling
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false, // Don't log binary audio data
      error: true,
    ));
    
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException error, ErrorInterceptorHandler handler) {
        print('API Error: ${error.message}');
        print('API Error Type: ${error.type}');
        print('API Error Response: ${error.response?.statusCode}');
        handler.next(error);
      },
    ));
  }
  
  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
  }
  
  String get baseUrl => _baseUrl;
  
  Future<bool> checkConnection() async {
    try {
      final response = await _dio.get(
        '/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Connection check failed: $e');
      return false;
    }
  }
  
  Future<Uint8List?> synthesizeSpeech({
    required String text,
    String? voice,
    double? speed,
    double? pitch,
    String? language,
    Map<String, dynamic>? additionalParams,
  }) async {
    try {
      final params = <String, dynamic>{
        'text': text,
      };
      
      if (voice != null) params['voice'] = voice;
      if (speed != null) params['speed'] = speed;
      if (pitch != null) params['pitch'] = pitch;
      if (language != null) params['language'] = language;
      
      if (additionalParams != null) {
        params.addAll(additionalParams);
      }
      
      final response = await _dio.post(
        '/synthesize',
        data: params,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'audio/wav',
          },
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Uint8List;
      }
      
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiException('Connection timeout', ApiErrorType.timeout);
      } else if (e.type == DioExceptionType.connectionError) {
        throw ApiException('Connection failed', ApiErrorType.networkError);
      } else if (e.response != null) {
        final statusCode = e.response!.statusCode ?? 0;
        if (statusCode >= 500) {
          throw ApiException('Server error', ApiErrorType.serverError);
        } else if (statusCode >= 400) {
          throw ApiException('Bad request', ApiErrorType.badRequest);
        }
      }
      throw ApiException('Unknown error: ${e.message}', ApiErrorType.unknown);
    } catch (e) {
      throw ApiException('Unexpected error: $e', ApiErrorType.unknown);
    }
  }
  
  Future<List<String>> getAvailableVoices() async {
    try {
      final response = await _dio.get(
        '/voices',
        options: Options(
          responseType: ResponseType.json,
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        if (response.data is List) {
          return (response.data as List).map((v) => v.toString()).toList();
        } else if (response.data is Map && response.data['voices'] != null) {
          return (response.data['voices'] as List)
              .map((v) => v.toString())
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Failed to get voices: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> getServerInfo() async {
    try {
      final response = await _dio.get(
        '/info',
        options: Options(
          responseType: ResponseType.json,
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      
      return {};
    } catch (e) {
      print('Failed to get server info: $e');
      return {};
    }
  }
  
  void dispose() {
    _dio.close();
  }
}

enum ApiErrorType {
  networkError,
  timeout,
  serverError,
  badRequest,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final ApiErrorType type;
  
  ApiException(this.message, this.type);
  
  @override
  String toString() => 'ApiException: $message (type: $type)';
}