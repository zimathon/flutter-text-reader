import 'package:just_audio/just_audio.dart';

enum PlaybackStatus {
  idle,
  loading,
  playing,
  paused,
  buffering,
  completed,
  error,
}

class PlaybackState {
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final double speed;
  final double volume;
  final String? currentBookId;
  final int currentChunkIndex;
  final int totalChunks;
  final String? errorMessage;
  final bool isBuffering;

  PlaybackState({
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.volume = 1.0,
    this.currentBookId,
    this.currentChunkIndex = 0,
    this.totalChunks = 0,
    this.errorMessage,
    this.isBuffering = false,
  });

  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isPaused => status == PlaybackStatus.paused;
  bool get isIdle => status == PlaybackStatus.idle;
  bool get hasError => status == PlaybackStatus.error;
  bool get isCompleted => status == PlaybackStatus.completed;

  PlaybackState copyWith({
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    double? speed,
    double? volume,
    String? currentBookId,
    int? currentChunkIndex,
    int? totalChunks,
    String? errorMessage,
    bool? isBuffering,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      currentBookId: currentBookId ?? this.currentBookId,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
      totalChunks: totalChunks ?? this.totalChunks,
      errorMessage: errorMessage ?? this.errorMessage,
      isBuffering: isBuffering ?? this.isBuffering,
    );
  }

  factory PlaybackState.fromProcessingState(
    ProcessingState processingState,
    PlaybackState currentState,
  ) {
    PlaybackStatus status;
    switch (processingState) {
      case ProcessingState.idle:
        status = PlaybackStatus.idle;
        break;
      case ProcessingState.loading:
        status = PlaybackStatus.loading;
        break;
      case ProcessingState.buffering:
        status = PlaybackStatus.buffering;
        break;
      case ProcessingState.ready:
        status = currentState.status == PlaybackStatus.playing
            ? PlaybackStatus.playing
            : PlaybackStatus.paused;
        break;
      case ProcessingState.completed:
        status = PlaybackStatus.completed;
        break;
    }
    
    return currentState.copyWith(
      status: status,
      isBuffering: processingState == ProcessingState.buffering,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.toString().split('.').last,
      'position': position.inMilliseconds,
      'duration': duration.inMilliseconds,
      'speed': speed,
      'volume': volume,
      'currentBookId': currentBookId,
      'currentChunkIndex': currentChunkIndex,
      'totalChunks': totalChunks,
      'errorMessage': errorMessage,
      'isBuffering': isBuffering,
    };
  }

  factory PlaybackState.fromJson(Map<String, dynamic> json) {
    return PlaybackState(
      status: PlaybackStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => PlaybackStatus.idle,
      ),
      position: Duration(milliseconds: json['position'] as int? ?? 0),
      duration: Duration(milliseconds: json['duration'] as int? ?? 0),
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      currentBookId: json['currentBookId'] as String?,
      currentChunkIndex: json['currentChunkIndex'] as int? ?? 0,
      totalChunks: json['totalChunks'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
      isBuffering: json['isBuffering'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'PlaybackState(status: $status, position: $position, duration: $duration, speed: $speed)';
  }
}