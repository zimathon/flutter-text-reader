import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/audio_chunk.dart';
import '../../models/speech_config.dart';

/// Cancellation token for cancelling speech synthesis operations
class CancellationToken {
  final _cancelCompleter = Completer<void>();
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;
  Future<void> get onCancel => _cancelCompleter.future;

  void cancel() {
    if (!_isCancelled) {
      _isCancelled = true;
      _cancelCompleter.complete();
    }
  }
}

/// Abstract interface for speech synthesis engines
abstract interface class SpeechEngine {
  /// Synthesize text to audio chunks
  Stream<AudioChunk> synthesize(
    String text, {
    SpeechConfig? config,
    CancellationToken? cancellationToken,
  });

  /// Whether this engine works offline
  bool get isOffline;

  /// Whether this engine supports streaming
  bool get supportsStreaming;

  /// Maximum text length this engine can handle
  int get maxTextLength;

  /// Current engine status
  EngineStatus get status;

  /// Initialize the engine
  Future<void> initialize();

  /// Dispose of engine resources
  Future<void> dispose();

  /// Check if the engine is available and ready
  Future<bool> checkAvailability();

  /// Get available voices for this engine
  Future<List<VoiceInfo>> getAvailableVoices();

  /// Validate text before synthesis
  bool validateText(String text) {
    return text.isNotEmpty && text.length <= maxTextLength;
  }
}

/// Engine status enumeration
enum EngineStatus {
  uninitialized,
  initializing,
  ready,
  busy,
  error,
  disposed,
}

/// Voice information
@immutable
class VoiceInfo {
  final String id;
  final String name;
  final String languageCode;
  final String gender;
  final bool isOnline;

  const VoiceInfo({
    required this.id,
    required this.name,
    required this.languageCode,
    required this.gender,
    this.isOnline = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoiceInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VoiceInfo($name, $languageCode)';
}

/// Base class for speech engine implementations
abstract class BaseSpeechEngine implements SpeechEngine {
  EngineStatus _status = EngineStatus.uninitialized;
  
  @override
  EngineStatus get status => _status;

  @protected
  set status(EngineStatus newStatus) {
    _status = newStatus;
  }

  @override
  bool validateText(String text) {
    if (text.isEmpty) {
      debugPrint('SpeechEngine: Text is empty');
      return false;
    }
    if (text.length > maxTextLength) {
      debugPrint('SpeechEngine: Text exceeds maximum length ($maxTextLength)');
      return false;
    }
    return true;
  }

  @protected
  Stream<AudioChunk> handleCancellation(
    Stream<AudioChunk> stream,
    CancellationToken? token,
  ) {
    if (token == null) return stream;

    return stream.takeWhile((_) => !token.isCancelled).handleError(
      (error) {
        if (token.isCancelled) {
          debugPrint('SpeechEngine: Synthesis cancelled');
          return;
        }
        throw error;
      },
    );
  }
}