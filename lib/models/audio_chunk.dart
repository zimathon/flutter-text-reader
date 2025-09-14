import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Represents a chunk of audio data from the speech synthesis engine
class AudioChunk {
  final Uint8List data;
  final int sequenceNumber;
  final bool isLast;
  final Duration? timestamp;
  final TextRange? textRange;

  const AudioChunk({
    required this.data,
    required this.sequenceNumber,
    this.isLast = false,
    this.timestamp,
    this.textRange,
  });

  /// Create an empty chunk (used for initialization)
  factory AudioChunk.empty() {
    return AudioChunk(
      data: Uint8List(0),
      sequenceNumber: 0,
      isLast: true,
    );
  }

  /// Size of the audio data in bytes
  int get size => data.length;

  /// Whether this chunk has data
  bool get hasData => data.isNotEmpty;

  @override
  String toString() {
    return 'AudioChunk(seq: $sequenceNumber, size: $size, isLast: $isLast)';
  }
}