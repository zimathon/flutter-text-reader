import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_reader_app/services/vibevoice_service.dart';
import 'package:text_reader_app/services/api_client.dart';
import 'package:text_reader_app/services/storage_service.dart';
import 'package:text_reader_app/models/audio_segment.dart';
import 'package:text_reader_app/models/book.dart';
import 'package:text_reader_app/models/playback_state.dart';

class MockApiClient implements ApiClient {
  bool shouldSucceed = true;
  bool isConnected = false;
  String _baseUrl = 'http://localhost:5000';
  
  @override
  String get baseUrl => _baseUrl;
  
  @override
  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
  }
  
  @override
  Future<bool> checkConnection() async {
    return isConnected;
  }
  
  @override
  Future<Uint8List?> synthesizeSpeech({
    required String text,
    String? voice,
    double? speed,
    double? pitch,
    String? language,
    Map<String, dynamic>? additionalParams,
  }) async {
    if (!shouldSucceed) {
      throw ApiException('Test error', ApiErrorType.serverError);
    }
    
    // Return mock audio data
    return Uint8List.fromList([1, 2, 3, 4, 5]);
  }
  
  @override
  Future<List<String>> getAvailableVoices() async {
    return ['voice-ja-JP', 'voice-en-US'];
  }
  
  @override
  Future<Map<String, dynamic>> getServerInfo() async {
    return {'version': '1.0.0', 'status': 'running'};
  }
  
  @override
  void dispose() {}
}

class MockStorageService implements StorageService {
  String? _apiUrl = 'http://localhost:5000';
  
  @override
  Future<void> initialize() async {}
  
  @override
  Future<String?> getVibeVoiceApiUrl() async {
    return _apiUrl;
  }
  
  @override
  Future<bool> setVibeVoiceApiUrl(String url) async {
    _apiUrl = url;
    return true;
  }
  
  // Implement other required methods with defaults
  @override
  Future<List<Book>> loadBooks() async => [];
  
  @override
  Future<bool> addBook(Book book) async => true;
  
  @override
  Future<bool> deleteBook(String bookId) async => true;
  
  @override
  Future<bool> saveBooks(List<Book> books) async => true;
  
  @override
  Future<bool> updateBookProgress(String bookId, int position) async => true;
  
  @override
  Future<int?> getBookProgress(String bookId) async => null;
  
  @override
  Future<PlaybackState?> loadLastPlaybackState() async => null;
  
  @override
  Future<bool> savePlaybackState(PlaybackState state) async => true;
  
  @override
  Future<Map<String, dynamic>> loadSettings() async => {};
  
  @override
  Future<bool> saveSettings(Map<String, dynamic> settings) async => true;
  
  @override
  Future<bool> updateSetting(String key, dynamic value) async => true;
  
  @override
  Future<List<int>> getBookmarks(String bookId) async => [];
  
  @override
  Future<bool> addBookmark(String bookId, int position) async => true;
  
  @override
  Future<bool> removeBookmark(String bookId, int position) async => true;
  
  @override
  Future<bool> clearAllData() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('VibeVoiceService Tests', () {
    late VibeVoiceService service;
    late MockApiClient mockApiClient;
    late MockStorageService mockStorageService;
    
    setUp(() {
      mockApiClient = MockApiClient();
      mockStorageService = MockStorageService();
      service = VibeVoiceService(
        apiClient: mockApiClient,
        storageService: mockStorageService,
      );
    });
    
    tearDown(() {
      service.dispose();
    });
    
    group('Initialization', () {
      test('should initialize with API URL from storage', () async {
        mockApiClient.isConnected = true;
        await service.initialize();
        
        expect(mockApiClient.baseUrl, 'http://localhost:5000');
      });
      
      test('should handle unavailable service', () async {
        mockApiClient.isConnected = false;
        await service.initialize();
        
        expect(service.isAvailable, isFalse);
        expect(service.availableVoices, isEmpty);
      });
      
      test('should load available voices when connected', () async {
        mockApiClient.isConnected = true;
        await service.initialize();
        
        expect(service.isAvailable, isTrue);
        expect(service.availableVoices, contains('voice-ja-JP'));
        expect(service.currentVoice, 'voice-ja-JP'); // Should prefer Japanese
      });
    });
    
    group('Audio Generation', () {
      setUp(() async {
        mockApiClient.isConnected = true;
        await service.initialize();
      });
      
      test('should generate audio segment successfully', () async {
        final segment = AudioSegment(
          id: 'test-1',
          text: 'Test text',
          startPosition: 0,
          endPosition: 9,
        );
        
        mockApiClient.shouldSucceed = true;
        final result = await service.generateAudioSegment(segment);
        
        expect(result.status, AudioSegmentStatus.ready);
        expect(result.audioData, isNotNull);
        expect(result.audioData!.length, 5);
        expect(result.ttsEngine, 'vibevoice');
      });
      
      test('should handle API errors', () async {
        final segment = AudioSegment(
          id: 'test-2',
          text: 'Test text',
          startPosition: 0,
          endPosition: 9,
        );
        
        mockApiClient.shouldSucceed = false;
        final result = await service.generateAudioSegment(segment);
        
        expect(result.status, AudioSegmentStatus.error);
        expect(result.errorMessage, contains('API error'));
      });
      
      test('should return error when service unavailable', () async {
        service = VibeVoiceService(
          apiClient: mockApiClient,
          storageService: mockStorageService,
        );
        // Don't initialize to keep service unavailable
        
        final segment = AudioSegment(
          id: 'test-3',
          text: 'Test text',
          startPosition: 0,
          endPosition: 9,
        );
        
        final result = await service.generateAudioSegment(segment);
        
        expect(result.status, AudioSegmentStatus.error);
        expect(result.errorMessage, contains('not available'));
      });
    });
    
    group('Cache Management', () {
      setUp(() async {
        mockApiClient.isConnected = true;
        await service.initialize();
      });
      
      test('should use cached audio when available', () async {
        final segment = AudioSegment(
          id: 'test-cache',
          text: 'Cached text',
          startPosition: 0,
          endPosition: 11,
        );
        
        // First generation
        final result1 = await service.generateAudioSegment(segment);
        expect(result1.status, AudioSegmentStatus.ready);
        expect(service.cacheSize, 1);
        
        // Second generation should use cache
        final segment2 = segment.copyWith(id: 'test-cache-2');
        final result2 = await service.generateAudioSegment(segment2);
        expect(result2.status, AudioSegmentStatus.ready);
        expect(service.cacheSize, 1); // Should still be 1
      });
      
      test('should clear cache', () async {
        final segment = AudioSegment(
          id: 'test-clear',
          text: 'Text to cache',
          startPosition: 0,
          endPosition: 13,
        );
        
        await service.generateAudioSegment(segment);
        expect(service.cacheSize, 1);
        
        service.clearCache();
        expect(service.cacheSize, 0);
      });
    });
    
    group('Batch Processing', () {
      setUp(() async {
        mockApiClient.isConnected = true;
        await service.initialize();
      });
      
      test('should generate batch of segments', () async {
        final segments = [
          AudioSegment(
            id: 'batch-1',
            text: 'First segment',
            startPosition: 0,
            endPosition: 13,
          ),
          AudioSegment(
            id: 'batch-2',
            text: 'Second segment',
            startPosition: 14,
            endPosition: 28,
          ),
        ];
        
        int progressCount = 0;
        final results = await service.generateBatch(
          segments,
          onProgress: (current, total) {
            progressCount++;
            expect(current, lessThanOrEqualTo(total));
          },
        );
        
        expect(results.length, 2);
        expect(results.every((s) => s.status == AudioSegmentStatus.ready), isTrue);
        expect(progressCount, 2);
      });
    });
    
    group('Configuration', () {
      test('should update API URL', () async {
        mockApiClient.isConnected = false;
        await service.initialize();
        expect(service.isAvailable, isFalse);
        
        // Update to new URL and mark as connected
        mockApiClient.isConnected = true;
        await service.updateApiUrl('http://newserver:8000');
        
        expect(mockApiClient.baseUrl, 'http://newserver:8000');
        expect(service.isAvailable, isTrue);
      });
      
      test('should set voice if available', () async {
        mockApiClient.isConnected = true;
        await service.initialize();
        
        service.setVoice('voice-en-US');
        expect(service.currentVoice, 'voice-en-US');
        
        // Should not change for unavailable voice
        service.setVoice('voice-invalid');
        expect(service.currentVoice, 'voice-en-US');
      });
      
      test('should get status', () async {
        mockApiClient.isConnected = true;
        await service.initialize();
        
        final status = service.getStatus();
        
        expect(status['available'], isTrue);
        expect(status['apiUrl'], 'http://localhost:5000');
        expect(status['currentVoice'], 'voice-ja-JP');
        expect(status['availableVoices'], contains('voice-ja-JP'));
        expect(status['cacheSize'], 0);
      });
    });
  });
}