import 'dart:async';
import 'dart:isolate';
import 'text_chunk.dart';

/// Japanese text chunker that considers Japanese sentence structure
class JapaneseTextChunker {
  static const int maxChunkSize = 200; // Maximum characters per chunk
  static const int overlapSize = 20; // Overlap between chunks
  static const int minChunkSize = 50; // Minimum characters per chunk

  // Japanese punctuation marks
  static const String sentenceEnders = '。！？';
  static const String clauseSeparators = '、，';
  static const String quotationMarks = '「」『』""';
  static const String brackets = '（）()[]【】';

  /// Chunk text into segments optimized for Japanese TTS
  List<TextChunk> chunk(String text) {
    if (text.isEmpty) return [];

    final List<TextChunk> chunks = [];
    int currentIndex = 0;
    int chunkIndex = 0;

    while (currentIndex < text.length) {
      // Find the end of the current chunk
      final chunkEnd = _findChunkEnd(text, currentIndex);
      
      // Extract chunk text
      final chunkText = text.substring(currentIndex, chunkEnd);
      
      // Calculate overlap with previous chunk
      String? previousOverlap;
      if (chunks.isNotEmpty && currentIndex > 0) {
        final overlapStart = (currentIndex - overlapSize).clamp(0, text.length);
        previousOverlap = text.substring(overlapStart, currentIndex);
      }

      // Calculate overlap with next chunk
      String? nextOverlap;
      if (chunkEnd < text.length) {
        final overlapEnd = (chunkEnd + overlapSize).clamp(0, text.length);
        nextOverlap = text.substring(chunkEnd, overlapEnd);
      }

      // Create and add chunk
      chunks.add(TextChunk(
        text: chunkText,
        startIndex: currentIndex,
        endIndex: chunkEnd,
        chunkIndex: chunkIndex++,
        previousOverlap: previousOverlap,
        nextOverlap: nextOverlap,
        metadata: {
          'hasCompleteSentence': _hasCompleteSentence(chunkText),
          'language': 'ja',
        },
      ));

      currentIndex = chunkEnd;
    }

    return chunks;
  }

  /// Stream chunks for progressive processing
  Stream<TextChunk> chunkStream(String text) async* {
    if (text.isEmpty) return;

    int currentIndex = 0;
    int chunkIndex = 0;
    String? lastOverlap;

    while (currentIndex < text.length) {
      final chunkEnd = _findChunkEnd(text, currentIndex);
      final chunkText = text.substring(currentIndex, chunkEnd);

      String? nextOverlap;
      if (chunkEnd < text.length) {
        final overlapEnd = (chunkEnd + overlapSize).clamp(0, text.length);
        nextOverlap = text.substring(chunkEnd, overlapEnd);
      }

      yield TextChunk(
        text: chunkText,
        startIndex: currentIndex,
        endIndex: chunkEnd,
        chunkIndex: chunkIndex++,
        previousOverlap: lastOverlap,
        nextOverlap: nextOverlap,
        metadata: {
          'hasCompleteSentence': _hasCompleteSentence(chunkText),
          'language': 'ja',
        },
      );

      lastOverlap = nextOverlap;
      currentIndex = chunkEnd;

      // Allow other operations to run
      await Future.delayed(Duration.zero);
    }
  }

  /// Process large text in isolate
  static Future<List<TextChunk>> chunkInIsolate(String text) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_isolateChunker, [receivePort.sendPort, text]);
    return await receivePort.first as List<TextChunk>;
  }

  static void _isolateChunker(List<dynamic> args) {
    final SendPort sendPort = args[0];
    final String text = args[1];
    final chunker = JapaneseTextChunker();
    final chunks = chunker.chunk(text);
    sendPort.send(chunks);
  }

  /// Find the optimal end position for a chunk
  int _findChunkEnd(String text, int startIndex) {
    final maxEnd = (startIndex + maxChunkSize).clamp(0, text.length);
    final minEnd = (startIndex + minChunkSize).clamp(0, text.length);

    // If we're near the end, take everything
    if (maxEnd >= text.length) {
      return text.length;
    }

    // Try to find sentence end
    int bestEnd = _findSentenceEnd(text, startIndex, maxEnd);
    if (bestEnd > minEnd) {
      return bestEnd;
    }

    // Try to find clause separator
    bestEnd = _findClauseSeparator(text, startIndex, maxEnd);
    if (bestEnd > minEnd) {
      return bestEnd;
    }

    // Try to find line break
    bestEnd = _findLineBreak(text, startIndex, maxEnd);
    if (bestEnd > minEnd) {
      return bestEnd;
    }

    // Try to avoid breaking in the middle of brackets or quotes
    bestEnd = _avoidBreakingPairs(text, startIndex, maxEnd);
    if (bestEnd > minEnd) {
      return bestEnd;
    }

    // Default to max size
    return maxEnd;
  }

  /// Find the nearest sentence end
  int _findSentenceEnd(String text, int start, int maxEnd) {
    int lastSentenceEnd = -1;

    for (int i = maxEnd - 1; i > start + minChunkSize; i--) {
      if (sentenceEnders.contains(text[i])) {
        // Check if it's not inside quotes or brackets
        if (!_isInsidePair(text, i)) {
          return i + 1; // Include the punctuation
        }
        lastSentenceEnd = i + 1;
      }
    }

    return lastSentenceEnd > 0 ? lastSentenceEnd : -1;
  }

  /// Find the nearest clause separator
  int _findClauseSeparator(String text, int start, int maxEnd) {
    for (int i = maxEnd - 1; i > start + minChunkSize; i--) {
      if (clauseSeparators.contains(text[i])) {
        if (!_isInsidePair(text, i)) {
          return i + 1; // Include the separator
        }
      }
    }
    return -1;
  }

  /// Find the nearest line break
  int _findLineBreak(String text, int start, int maxEnd) {
    for (int i = maxEnd - 1; i > start + minChunkSize; i--) {
      if (text[i] == '\n') {
        return i + 1;
      }
    }
    return -1;
  }

  /// Avoid breaking inside paired punctuation
  int _avoidBreakingPairs(String text, int start, int maxEnd) {
    int openCount = 0;
    int lastSafeBreak = maxEnd;

    for (int i = start; i < maxEnd; i++) {
      final char = text[i];
      
      if ('「『("【（['.contains(char)) {
        openCount++;
      } else if ('」』)"】）]'.contains(char)) {
        openCount--;
      }

      if (openCount == 0 && i > start + minChunkSize) {
        lastSafeBreak = i;
      }
    }

    return openCount == 0 ? maxEnd : lastSafeBreak;
  }

  /// Check if position is inside quotes or brackets
  bool _isInsidePair(String text, int position) {
    int openCount = 0;
    
    for (int i = 0; i < position && i < text.length; i++) {
      final char = text[i];
      
      if ('「『("【（['.contains(char)) {
        openCount++;
      } else if ('」』)"】）]'.contains(char)) {
        openCount--;
      }
    }

    return openCount > 0;
  }

  /// Check if chunk contains at least one complete sentence
  bool _hasCompleteSentence(String text) {
    for (final ender in sentenceEnders.split('')) {
      if (text.contains(ender)) {
        return true;
      }
    }
    return false;
  }
}

/// Optimize chunks for better balance
class ChunkOptimizer {
  /// Optimize a list of chunks for better balance
  static List<TextChunk> optimize(List<TextChunk> chunks) {
    if (chunks.length <= 1) return chunks;

    final optimized = <TextChunk>[];
    
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      
      // Merge very short chunks with neighbors
      if (chunk.length < JapaneseTextChunker.minChunkSize && i < chunks.length - 1) {
        final nextChunk = chunks[i + 1];
        final mergedText = chunk.text + nextChunk.text;
        
        if (mergedText.length <= JapaneseTextChunker.maxChunkSize) {
          optimized.add(TextChunk(
            text: mergedText,
            startIndex: chunk.startIndex,
            endIndex: nextChunk.endIndex,
            chunkIndex: optimized.length,
            previousOverlap: chunk.previousOverlap,
            nextOverlap: nextChunk.nextOverlap,
            metadata: {
              'merged': true,
              'originalChunks': [chunk.chunkIndex, nextChunk.chunkIndex],
            },
          ));
          i++; // Skip next chunk
          continue;
        }
      }
      
      // Add chunk as-is
      optimized.add(chunk.copyWith(chunkIndex: optimized.length));
    }

    return optimized;
  }

  /// Calculate quality score for chunks
  static double calculateQuality(List<TextChunk> chunks) {
    if (chunks.isEmpty) return 0.0;

    double totalScore = 0.0;
    int sentenceCompleteCount = 0;
    double lengthVariance = 0.0;

    // Calculate average length
    final avgLength = chunks.map((c) => c.length).reduce((a, b) => a + b) / chunks.length;

    for (final chunk in chunks) {
      // Check sentence completeness
      if (chunk.metadata['hasCompleteSentence'] == true) {
        sentenceCompleteCount++;
      }

      // Calculate length variance
      lengthVariance += (chunk.length - avgLength).abs() / avgLength;
    }

    // Score based on sentence completeness (40%)
    totalScore += (sentenceCompleteCount / chunks.length) * 0.4;

    // Score based on length consistency (30%)
    final consistencyScore = 1.0 - (lengthVariance / chunks.length).clamp(0.0, 1.0);
    totalScore += consistencyScore * 0.3;

    // Score based on chunk count efficiency (30%)
    final efficiencyScore = 1.0 - (chunks.length / 100).clamp(0.0, 1.0);
    totalScore += efficiencyScore * 0.3;

    return totalScore;
  }
}