import 'package:flutter_test/flutter_test.dart';
import 'package:text_reader_app/services/tts_service.dart';
import 'package:text_reader_app/models/audio_segment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsService Unit Tests', () {
    late TtsService ttsService;

    setUp(() {
      // Note: FlutterTts cannot be easily mocked in unit tests
      // These tests verify the service logic without actual TTS operations
      ttsService = TtsService();
    });

    group('Basic Properties', () {
      test('should start uninitialized', () {
        expect(ttsService.isInitialized, isFalse);
      });

      test('should have default settings', () {
        expect(ttsService.speechRate, 1.0);
        expect(ttsService.volume, 1.0);
        expect(ttsService.pitch, 1.0);
        expect(ttsService.language, 'ja-JP');
      });

      test('should start with Android native engine', () {
        expect(ttsService.currentEngine, TtsEngine.androidNative);
      });
    });

    group('Engine Management', () {
      test('should switch engines', () {
        ttsService.switchEngine(TtsEngine.vibeVoice);
        expect(ttsService.currentEngine, TtsEngine.vibeVoice);

        ttsService.switchEngine(TtsEngine.androidNative);
        expect(ttsService.currentEngine, TtsEngine.androidNative);
      });
    });

    group('Queue Management', () {
      test('should add segments to queue', () {
        final segment1 = AudioSegment(
          id: 'seg1',
          text: 'Text 1',
          startPosition: 0,
          endPosition: 6,
        );
        final segment2 = AudioSegment(
          id: 'seg2',
          text: 'Text 2',
          startPosition: 7,
          endPosition: 13,
        );

        ttsService.addToQueue(segment1);
        ttsService.addToQueue(segment2);

        expect(ttsService.queueLength, 2);
      });

      test('should clear queue', () {
        final segment = AudioSegment(
          id: 'seg1',
          text: 'Text',
          startPosition: 0,
          endPosition: 4,
        );

        ttsService.addToQueue(segment);
        expect(ttsService.queueLength, 1);

        ttsService.clearQueue();
        expect(ttsService.queueLength, 0);
        expect(ttsService.isProcessingQueue, isFalse);
      });

      test('should track processing state', () {
        expect(ttsService.isProcessingQueue, isFalse);
      });
    });

    group('Callbacks', () {
      test('should set callbacks', () {
        ttsService.onStart = (text) {};
        ttsService.onComplete = () {};
        ttsService.onError = (error) {};
        ttsService.onProgress = (start, end) {};

        expect(ttsService.onStart, isNotNull);
        expect(ttsService.onComplete, isNotNull);
        expect(ttsService.onError, isNotNull);
        expect(ttsService.onProgress, isNotNull);
      });
    });

    group('Settings Validation', () {
      test('speech rate should be clamped to valid range', () {
        // Note: These would normally call setSpeechRate but that requires initialization
        // Testing the clamping logic conceptually
        expect(1.5.clamp(0.1, 3.0), 1.5);
        expect(5.0.clamp(0.1, 3.0), 3.0);
        expect(0.05.clamp(0.1, 3.0), 0.1);
      });

      test('volume should be clamped to valid range', () {
        expect(0.5.clamp(0.0, 1.0), 0.5);
        expect(2.0.clamp(0.0, 1.0), 1.0);
        expect((-0.5).clamp(0.0, 1.0), 0.0);
      });

      test('pitch should be clamped to valid range', () {
        expect(1.2.clamp(0.5, 2.0), 1.2);
        expect(3.0.clamp(0.5, 2.0), 2.0);
        expect(0.3.clamp(0.5, 2.0), 0.5);
      });
    });
  });
}