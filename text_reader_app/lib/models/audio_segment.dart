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

  static List<TextChunk> splitText(String text, {int maxChunkSize = 5000}) {
    if (text.isEmpty) return [];

    final chunks = <TextChunk>[];
    final paragraphs = text.split(RegExp(r'\n\n+'));
    
    var currentChunk = StringBuffer();
    var currentStartPosition = 0;
    var currentPosition = 0;
    var chunkIndex = 0;

    for (final paragraph in paragraphs) {
      final paragraphWithNewlines = '$paragraph\n\n';
      final paragraphLength = paragraphWithNewlines.length;

      if (currentChunk.length + paragraphLength > maxChunkSize && 
          currentChunk.isNotEmpty) {
        final chunkText = currentChunk.toString().trimRight();
        chunks.add(TextChunk(
          id: 'chunk_$chunkIndex',
          text: chunkText,
          startPosition: currentStartPosition,
          endPosition: currentPosition,
          chunkIndex: chunkIndex,
          totalChunks: 0,
        ));
        
        chunkIndex++;
        currentChunk.clear();
        currentStartPosition = currentPosition;
      }

      currentChunk.write(paragraphWithNewlines);
      currentPosition += paragraphLength;
    }

    if (currentChunk.isNotEmpty) {
      final chunkText = currentChunk.toString().trimRight();
      chunks.add(TextChunk(
        id: 'chunk_$chunkIndex',
        text: chunkText,
        startPosition: currentStartPosition,
        endPosition: currentPosition,
        chunkIndex: chunkIndex,
        totalChunks: 0,
      ));
    }

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
}