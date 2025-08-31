import 'dart:typed_data';

enum AudioSegmentStatus {
  pending,
  generating,
  ready,
  playing,
  played,
  error,
}

class AudioSegment {
  final String id;
  final String text;
  final int startPosition;
  final int endPosition;
  final String? audioFilePath;
  final Uint8List? audioData;
  final Duration? duration;
  final AudioSegmentStatus status;
  final String? errorMessage;
  final DateTime? generatedAt;
  final String ttsEngine;

  AudioSegment({
    required this.id,
    required this.text,
    required this.startPosition,
    required this.endPosition,
    this.audioFilePath,
    this.audioData,
    this.duration,
    this.status = AudioSegmentStatus.pending,
    this.errorMessage,
    this.generatedAt,
    this.ttsEngine = 'vibevoice',
  });

  int get textLength => endPosition - startPosition;

  bool get isReady => status == AudioSegmentStatus.ready;
  bool get hasError => status == AudioSegmentStatus.error;
  bool get isGenerating => status == AudioSegmentStatus.generating;
  bool get isPending => status == AudioSegmentStatus.pending;

  AudioSegment copyWith({
    String? id,
    String? text,
    int? startPosition,
    int? endPosition,
    String? audioFilePath,
    Uint8List? audioData,
    Duration? duration,
    AudioSegmentStatus? status,
    String? errorMessage,
    DateTime? generatedAt,
    String? ttsEngine,
  }) {
    return AudioSegment(
      id: id ?? this.id,
      text: text ?? this.text,
      startPosition: startPosition ?? this.startPosition,
      endPosition: endPosition ?? this.endPosition,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      audioData: audioData ?? this.audioData,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      generatedAt: generatedAt ?? this.generatedAt,
      ttsEngine: ttsEngine ?? this.ttsEngine,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'startPosition': startPosition,
      'endPosition': endPosition,
      'audioFilePath': audioFilePath,
      'duration': duration?.inMilliseconds,
      'status': status.toString().split('.').last,
      'errorMessage': errorMessage,
      'generatedAt': generatedAt?.toIso8601String(),
      'ttsEngine': ttsEngine,
    };
  }

  factory AudioSegment.fromJson(Map<String, dynamic> json) {
    return AudioSegment(
      id: json['id'] as String,
      text: json['text'] as String,
      startPosition: json['startPosition'] as int,
      endPosition: json['endPosition'] as int,
      audioFilePath: json['audioFilePath'] as String?,
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      status: AudioSegmentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => AudioSegmentStatus.pending,
      ),
      errorMessage: json['errorMessage'] as String?,
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : null,
      ttsEngine: json['ttsEngine'] as String? ?? 'vibevoice',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSegment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class TextChunk {
  final String id;
  final String text;
  final int startPosition;
  final int endPosition;
  final int chunkIndex;
  final int totalChunks;

  TextChunk({
    required this.id,
    required this.text,
    required this.startPosition,
    required this.endPosition,
    required this.chunkIndex,
    required this.totalChunks,
  });

  static List<TextChunk> splitText(String text, {int maxChunkSize = 1000}) {
    if (text.isEmpty) return [];

    final chunks = <TextChunk>[];
    var currentPosition = 0;
    var chunkIndex = 0;
    
    // Japanese and English sentence endings
    final sentenceEndings = RegExp(r'[。！？\.!?]\s*');
    final paragraphBreaks = RegExp(r'\n\n+');
    
    while (currentPosition < text.length) {
      var endPosition = currentPosition + maxChunkSize;
      
      // Don't exceed text length
      if (endPosition >= text.length) {
        endPosition = text.length;
      } else {
        // Try to find a good break point
        var searchStart = (currentPosition + maxChunkSize * 0.8).round();
        searchStart = searchStart.clamp(currentPosition, text.length - 1);
        
        // First, try to break at paragraph
        final paragraphMatch = paragraphBreaks.firstMatch(
          text.substring(searchStart, endPosition),
        );
        
        if (paragraphMatch != null) {
          endPosition = searchStart + paragraphMatch.end;
        } else {
          // Try to break at sentence ending
          final sentenceMatches = sentenceEndings.allMatches(
            text.substring(searchStart, endPosition),
          );
          
          if (sentenceMatches.isNotEmpty) {
            final lastMatch = sentenceMatches.last;
            endPosition = searchStart + lastMatch.end;
          } else {
            // Look for any punctuation or space
            final punctuationIndex = text.lastIndexOf(
              RegExp(r'[、,\s]'),
              endPosition - 1,
              currentPosition + (maxChunkSize * 0.5).round(),
            );
            
            if (punctuationIndex > currentPosition) {
              endPosition = punctuationIndex + 1;
            }
          }
        }
      }
      
      // Extract chunk text
      final chunkText = text.substring(currentPosition, endPosition).trim();
      
      if (chunkText.isNotEmpty) {
        chunks.add(TextChunk(
          id: 'chunk_${chunkIndex.toString().padLeft(3, '0')}',
          text: chunkText,
          startPosition: currentPosition,
          endPosition: endPosition,
          chunkIndex: chunkIndex,
          totalChunks: 0, // Will be updated below
        ));
        chunkIndex++;
      }
      
      currentPosition = endPosition;
      
      // Skip whitespace at the beginning of next chunk
      while (currentPosition < text.length && 
             (text[currentPosition] == ' ' || 
              text[currentPosition] == '\n' || 
              text[currentPosition] == '\t')) {
        currentPosition++;
      }
    }
    
    // Update total chunks count
    final totalChunks = chunks.length;
    return chunks.map((chunk) => TextChunk(
      id: chunk.id,
      text: chunk.text,
      startPosition: chunk.startPosition,
      endPosition: chunk.endPosition,
      chunkIndex: chunk.chunkIndex,
      totalChunks: totalChunks,
    )).toList();
  }
  
  static List<TextChunk> splitTextAdvanced(
    String text, {
    int maxChunkSize = 1000,
    int overlapSize = 50,
  }) {
    final chunks = splitText(text, maxChunkSize: maxChunkSize);
    
    if (overlapSize <= 0 || chunks.length <= 1) {
      return chunks;
    }
    
    // Add overlap between chunks for better context
    final overlappedChunks = <TextChunk>[];
    
    for (int i = 0; i < chunks.length; i++) {
      var chunkText = chunks[i].text;
      var startPos = chunks[i].startPosition;
      var endPos = chunks[i].endPosition;
      
      // Add overlap from previous chunk
      if (i > 0) {
        final prevChunk = chunks[i - 1];
        final overlapStart = (prevChunk.text.length - overlapSize)
            .clamp(0, prevChunk.text.length);
        final overlap = prevChunk.text.substring(overlapStart);
        chunkText = '$overlap $chunkText';
        startPos = (prevChunk.endPosition - overlap.length)
            .clamp(0, prevChunk.endPosition);
      }
      
      // Add overlap from next chunk
      if (i < chunks.length - 1) {
        final nextChunk = chunks[i + 1];
        final overlapEnd = overlapSize.clamp(0, nextChunk.text.length);
        final overlap = nextChunk.text.substring(0, overlapEnd);
        chunkText = '$chunkText $overlap';
        endPos = (nextChunk.startPosition + overlap.length)
            .clamp(nextChunk.startPosition, text.length);
      }
      
      overlappedChunks.add(TextChunk(
        id: chunks[i].id,
        text: chunkText,
        startPosition: startPos,
        endPosition: endPos,
        chunkIndex: i,
        totalChunks: chunks.length,
      ));
    }
    
    return overlappedChunks;
  }
}