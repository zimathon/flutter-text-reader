import 'package:flutter/foundation.dart';

/// Represents a chunk of text for processing
@immutable
class TextChunk {
  final String text;
  final int startIndex;
  final int endIndex;
  final int chunkIndex;
  final String? previousOverlap;
  final String? nextOverlap;
  final Map<String, dynamic> metadata;

  const TextChunk({
    required this.text,
    required this.startIndex,
    required this.endIndex,
    required this.chunkIndex,
    this.previousOverlap,
    this.nextOverlap,
    this.metadata = const {},
  });

  /// Get the actual length of the text chunk
  int get length => endIndex - startIndex;

  /// Check if this chunk has overlap with previous chunk
  bool get hasPreviousOverlap => previousOverlap != null && previousOverlap!.isNotEmpty;

  /// Check if this chunk has overlap with next chunk
  bool get hasNextOverlap => nextOverlap != null && nextOverlap!.isNotEmpty;

  /// Create a copy with modified fields
  TextChunk copyWith({
    String? text,
    int? startIndex,
    int? endIndex,
    int? chunkIndex,
    String? previousOverlap,
    String? nextOverlap,
    Map<String, dynamic>? metadata,
  }) {
    return TextChunk(
      text: text ?? this.text,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      previousOverlap: previousOverlap ?? this.previousOverlap,
      nextOverlap: nextOverlap ?? this.nextOverlap,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'TextChunk(index: $chunkIndex, range: $startIndex-$endIndex, length: $length)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextChunk &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          startIndex == other.startIndex &&
          endIndex == other.endIndex &&
          chunkIndex == other.chunkIndex;

  @override
  int get hashCode =>
      text.hashCode ^
      startIndex.hashCode ^
      endIndex.hashCode ^
      chunkIndex.hashCode;
}

/// Language detection result
enum TextLanguage {
  japanese,
  english,
  chinese,
  korean,
  mixed,
  unknown,
}

/// Language detection result with confidence
class LanguageDetectionResult {
  final TextLanguage primaryLanguage;
  final Map<TextLanguage, double> languageRatios;
  final double confidence;

  const LanguageDetectionResult({
    required this.primaryLanguage,
    required this.languageRatios,
    required this.confidence,
  });

  bool get isMixed => languageRatios.values.where((v) => v > 0.1).length > 1;
}