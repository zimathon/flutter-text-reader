import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Audio engine interface for TTS implementations
abstract class AudioEngine {
  /// Engine name for display
  String get name;
  
  /// Whether the engine is currently available
  Future<bool> get isAvailable;
  
  /// Whether the engine requires network connection
  bool get requiresNetwork;
  
  /// Generate audio from text
  Future<Uint8List> synthesize({
    required String text,
    String? voice,
    double speed = 1.0,
    double pitch = 1.0,
    String? language,
  });
  
  /// Get available voices
  Future<List<VoiceInfo>> getAvailableVoices({String? language});
  
  /// Initialize the engine
  Future<void> initialize();
  
  /// Dispose resources
  Future<void> dispose();
}

/// Voice information
@immutable
class VoiceInfo {
  final String id;
  final String name;
  final String language;
  final String? gender;
  final bool isDefault;

  const VoiceInfo({
    required this.id,
    required this.name,
    required this.language,
    this.gender,
    this.isDefault = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}