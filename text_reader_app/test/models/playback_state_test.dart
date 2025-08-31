import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:text_reader_app/models/playback_state.dart';

void main() {
  group('PlaybackState Model Tests', () {
    test('should create PlaybackState with default values', () {
      final state = PlaybackState();
      
      expect(state.status, PlaybackStatus.idle);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
      expect(state.speed, 1.0);
      expect(state.volume, 1.0);
      expect(state.currentBookId, isNull);
      expect(state.currentChunkIndex, 0);
      expect(state.totalChunks, 0);
      expect(state.errorMessage, isNull);
      expect(state.isBuffering, isFalse);
    });

    test('should calculate progress correctly', () {
      final state = PlaybackState(
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 100),
      );
      expect(state.progress, 0.3);

      final completedState = PlaybackState(
        position: const Duration(seconds: 100),
        duration: const Duration(seconds: 100),
      );
      expect(completedState.progress, 1.0);

      final emptyState = PlaybackState();
      expect(emptyState.progress, 0.0);
    });

    test('should check status convenience methods', () {
      final playingState = PlaybackState(status: PlaybackStatus.playing);
      expect(playingState.isPlaying, isTrue);
      expect(playingState.isPaused, isFalse);
      expect(playingState.isIdle, isFalse);

      final pausedState = PlaybackState(status: PlaybackStatus.paused);
      expect(pausedState.isPlaying, isFalse);
      expect(pausedState.isPaused, isTrue);

      final errorState = PlaybackState(
        status: PlaybackStatus.error,
        errorMessage: 'Test error',
      );
      expect(errorState.hasError, isTrue);

      final completedState = PlaybackState(status: PlaybackStatus.completed);
      expect(completedState.isCompleted, isTrue);
    });

    test('should copy with new values correctly', () {
      final original = PlaybackState(
        status: PlaybackStatus.playing,
        position: const Duration(seconds: 10),
        speed: 1.5,
      );

      final copied = original.copyWith(
        status: PlaybackStatus.paused,
        position: const Duration(seconds: 20),
      );

      expect(copied.status, PlaybackStatus.paused);
      expect(copied.position, const Duration(seconds: 20));
      expect(copied.speed, 1.5);
    });

    test('should convert from ProcessingState correctly', () {
      final currentState = PlaybackState(status: PlaybackStatus.playing);

      final idleState = PlaybackState.fromProcessingState(
        ProcessingState.idle,
        currentState,
      );
      expect(idleState.status, PlaybackStatus.idle);

      final loadingState = PlaybackState.fromProcessingState(
        ProcessingState.loading,
        currentState,
      );
      expect(loadingState.status, PlaybackStatus.loading);

      final bufferingState = PlaybackState.fromProcessingState(
        ProcessingState.buffering,
        currentState,
      );
      expect(bufferingState.status, PlaybackStatus.buffering);
      expect(bufferingState.isBuffering, isTrue);

      final readyPlayingState = PlaybackState.fromProcessingState(
        ProcessingState.ready,
        PlaybackState(status: PlaybackStatus.playing),
      );
      expect(readyPlayingState.status, PlaybackStatus.playing);

      final readyPausedState = PlaybackState.fromProcessingState(
        ProcessingState.ready,
        PlaybackState(status: PlaybackStatus.paused),
      );
      expect(readyPausedState.status, PlaybackStatus.paused);

      final completedState = PlaybackState.fromProcessingState(
        ProcessingState.completed,
        currentState,
      );
      expect(completedState.status, PlaybackStatus.completed);
    });

    test('should serialize to JSON correctly', () {
      final state = PlaybackState(
        status: PlaybackStatus.playing,
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 5),
        speed: 1.5,
        volume: 0.8,
        currentBookId: 'book-123',
        currentChunkIndex: 2,
        totalChunks: 10,
        errorMessage: 'Test error',
        isBuffering: true,
      );

      final json = state.toJson();
      
      expect(json['status'], 'playing');
      expect(json['position'], 30000);
      expect(json['duration'], 300000);
      expect(json['speed'], 1.5);
      expect(json['volume'], 0.8);
      expect(json['currentBookId'], 'book-123');
      expect(json['currentChunkIndex'], 2);
      expect(json['totalChunks'], 10);
      expect(json['errorMessage'], 'Test error');
      expect(json['isBuffering'], isTrue);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'status': 'playing',
        'position': 30000,
        'duration': 300000,
        'speed': 1.5,
        'volume': 0.8,
        'currentBookId': 'book-123',
        'currentChunkIndex': 2,
        'totalChunks': 10,
        'errorMessage': 'Test error',
        'isBuffering': true,
      };

      final state = PlaybackState.fromJson(json);
      
      expect(state.status, PlaybackStatus.playing);
      expect(state.position, const Duration(seconds: 30));
      expect(state.duration, const Duration(minutes: 5));
      expect(state.speed, 1.5);
      expect(state.volume, 0.8);
      expect(state.currentBookId, 'book-123');
      expect(state.currentChunkIndex, 2);
      expect(state.totalChunks, 10);
      expect(state.errorMessage, 'Test error');
      expect(state.isBuffering, isTrue);
    });

    test('should handle invalid status in JSON gracefully', () {
      final json = {
        'status': 'invalid_status',
        'position': 0,
        'duration': 0,
      };

      final state = PlaybackState.fromJson(json);
      expect(state.status, PlaybackStatus.idle);
    });

    test('should provide meaningful toString', () {
      final state = PlaybackState(
        status: PlaybackStatus.playing,
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 5),
        speed: 1.5,
      );

      final str = state.toString();
      expect(str, contains('playing'));
      expect(str, contains('0:00:30'));
      expect(str, contains('0:05:00'));
      expect(str, contains('1.5'));
    });
  });
}