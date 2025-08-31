import 'package:flutter_test/flutter_test.dart';
import 'package:text_reader_app/models/audio_segment.dart';

void main() {
  group('AudioSegment Model Tests', () {
    test('should create AudioSegment with default values', () {
      final segment = AudioSegment(
        id: 'segment-1',
        text: 'Test text',
        startPosition: 0,
        endPosition: 9,
      );

      expect(segment.id, 'segment-1');
      expect(segment.text, 'Test text');
      expect(segment.startPosition, 0);
      expect(segment.endPosition, 9);
      expect(segment.status, AudioSegmentStatus.pending);
      expect(segment.ttsEngine, 'vibevoice');
      expect(segment.audioFilePath, isNull);
      expect(segment.audioData, isNull);
      expect(segment.duration, isNull);
      expect(segment.errorMessage, isNull);
    });

    test('should calculate text length correctly', () {
      final segment = AudioSegment(
        id: 'segment-1',
        text: 'Test text',
        startPosition: 10,
        endPosition: 25,
      );

      expect(segment.textLength, 15);
    });

    test('should check status convenience methods', () {
      final readySegment = AudioSegment(
        id: 'segment-1',
        text: 'Test',
        startPosition: 0,
        endPosition: 4,
        status: AudioSegmentStatus.ready,
      );
      expect(readySegment.isReady, isTrue);
      expect(readySegment.hasError, isFalse);
      expect(readySegment.isGenerating, isFalse);
      expect(readySegment.isPending, isFalse);

      final errorSegment = AudioSegment(
        id: 'segment-2',
        text: 'Test',
        startPosition: 0,
        endPosition: 4,
        status: AudioSegmentStatus.error,
        errorMessage: 'TTS failed',
      );
      expect(errorSegment.hasError, isTrue);
      expect(errorSegment.isReady, isFalse);

      final generatingSegment = AudioSegment(
        id: 'segment-3',
        text: 'Test',
        startPosition: 0,
        endPosition: 4,
        status: AudioSegmentStatus.generating,
      );
      expect(generatingSegment.isGenerating, isTrue);

      final pendingSegment = AudioSegment(
        id: 'segment-4',
        text: 'Test',
        startPosition: 0,
        endPosition: 4,
        status: AudioSegmentStatus.pending,
      );
      expect(pendingSegment.isPending, isTrue);
    });

    test('should copy with new values correctly', () {
      final original = AudioSegment(
        id: 'segment-1',
        text: 'Original text',
        startPosition: 0,
        endPosition: 13,
        status: AudioSegmentStatus.pending,
      );

      final copied = original.copyWith(
        status: AudioSegmentStatus.ready,
        audioFilePath: '/path/to/audio.mp3',
        duration: const Duration(seconds: 5),
      );

      expect(copied.status, AudioSegmentStatus.ready);
      expect(copied.audioFilePath, '/path/to/audio.mp3');
      expect(copied.duration, const Duration(seconds: 5));
      expect(copied.text, 'Original text');
      expect(copied.id, 'segment-1');
    });

    test('should serialize to JSON correctly', () {
      final now = DateTime.now();
      final segment = AudioSegment(
        id: 'segment-1',
        text: 'Test text',
        startPosition: 0,
        endPosition: 9,
        audioFilePath: '/path/to/audio.mp3',
        duration: const Duration(seconds: 10),
        status: AudioSegmentStatus.ready,
        generatedAt: now,
        ttsEngine: 'android-tts',
      );

      final json = segment.toJson();

      expect(json['id'], 'segment-1');
      expect(json['text'], 'Test text');
      expect(json['startPosition'], 0);
      expect(json['endPosition'], 9);
      expect(json['audioFilePath'], '/path/to/audio.mp3');
      expect(json['duration'], 10000);
      expect(json['status'], 'ready');
      expect(json['generatedAt'], now.toIso8601String());
      expect(json['ttsEngine'], 'android-tts');
    });

    test('should deserialize from JSON correctly', () {
      final now = DateTime.now();
      final json = {
        'id': 'segment-1',
        'text': 'Test text',
        'startPosition': 0,
        'endPosition': 9,
        'audioFilePath': '/path/to/audio.mp3',
        'duration': 10000,
        'status': 'ready',
        'generatedAt': now.toIso8601String(),
        'ttsEngine': 'android-tts',
      };

      final segment = AudioSegment.fromJson(json);

      expect(segment.id, 'segment-1');
      expect(segment.text, 'Test text');
      expect(segment.startPosition, 0);
      expect(segment.endPosition, 9);
      expect(segment.audioFilePath, '/path/to/audio.mp3');
      expect(segment.duration, const Duration(seconds: 10));
      expect(segment.status, AudioSegmentStatus.ready);
      expect(segment.ttsEngine, 'android-tts');
    });

    test('should implement equality based on id', () {
      final segment1 = AudioSegment(
        id: 'segment-1',
        text: 'Text 1',
        startPosition: 0,
        endPosition: 6,
      );

      final segment2 = AudioSegment(
        id: 'segment-1',
        text: 'Different text',
        startPosition: 10,
        endPosition: 24,
      );

      final segment3 = AudioSegment(
        id: 'segment-2',
        text: 'Text 1',
        startPosition: 0,
        endPosition: 6,
      );

      expect(segment1 == segment2, isTrue);
      expect(segment1 == segment3, isFalse);
      expect(segment1.hashCode, segment2.hashCode);
    });
  });

  group('TextChunk Tests', () {
    test('should split text into chunks correctly', () {
      final text = '''First paragraph.

Second paragraph with more content.

Third paragraph.

Fourth paragraph that is much longer and contains more text to potentially exceed chunk size limits if we set a small max size.

Fifth paragraph.''';

      final chunks = TextChunk.splitText(text, maxChunkSize: 100);

      expect(chunks.length, greaterThan(1));
      expect(chunks.first.chunkIndex, 0);
      expect(chunks.last.totalChunks, chunks.length);
      
      for (int i = 0; i < chunks.length; i++) {
        expect(chunks[i].chunkIndex, i);
        expect(chunks[i].totalChunks, chunks.length);
        expect(chunks[i].id, 'chunk_$i');
      }
    });

    test('should handle empty text', () {
      final chunks = TextChunk.splitText('');
      expect(chunks, isEmpty);
    });

    test('should handle single paragraph smaller than max size', () {
      final text = 'This is a single paragraph.';
      final chunks = TextChunk.splitText(text, maxChunkSize: 100);

      expect(chunks.length, 1);
      expect(chunks.first.text, text);
      expect(chunks.first.startPosition, 0);
      expect(chunks.first.endPosition, text.length + 2); // +2 for added newlines
      expect(chunks.first.chunkIndex, 0);
      expect(chunks.first.totalChunks, 1);
    });

    test('should preserve paragraph boundaries', () {
      final text = '''First paragraph.

Second paragraph.

Third paragraph.''';

      final chunks = TextChunk.splitText(text, maxChunkSize: 30);

      for (final chunk in chunks) {
        expect(chunk.text.trim(), isNotEmpty);
        expect(chunk.text, isNot(startsWith('\n\n')));
      }
    });

    test('should track positions correctly', () {
      final text = '''First.

Second.

Third.''';

      final chunks = TextChunk.splitText(text, maxChunkSize: 15);

      if (chunks.length > 1) {
        expect(chunks[0].endPosition, chunks[1].startPosition);
      }
      if (chunks.length > 2) {
        expect(chunks[1].endPosition, chunks[2].startPosition);
      }
    });

    test('should handle very long paragraphs', () {
      final longParagraph = 'a' * 1000;
      final text = '$longParagraph\n\nShort paragraph.';
      
      final chunks = TextChunk.splitText(text, maxChunkSize: 100);

      expect(chunks.length, greaterThanOrEqualTo(2));
      expect(chunks.first.text, contains('a' * 100));
    });
  });
}