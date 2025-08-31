import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:just_audio/just_audio.dart';
import 'package:text_reader_app/models/audio_segment.dart';
import 'package:text_reader_app/models/playback_state.dart';
import 'package:text_reader_app/services/tts_service.dart';

class AudioPlaybackService extends audio_service.BaseAudioHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TtsService _ttsService;
  
  // Current playback state
  PlaybackState _currentState = PlaybackState();
  String? _currentBookId;
  
  // Audio segments queue
  final List<AudioSegment> _segmentQueue = [];
  int _currentSegmentIndex = 0;
  
  // Stream controllers
  final _playbackStateController = StreamController<PlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _speedController = StreamController<double>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  
  // Callbacks
  Function(String)? onSegmentStart;
  Function(String)? onSegmentComplete;
  Function(String, String)? onError;
  
  AudioPlaybackService({TtsService? ttsService})
      : _ttsService = ttsService ?? TtsService() {
    _initializePlayer();
  }
  
  void _initializePlayer() {
    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((playerState) {
      _updatePlaybackState(playerState);
    });
    
    // Listen to position changes
    _audioPlayer.positionStream.listen((position) {
      _positionController.add(position);
      _currentState = _currentState.copyWith(position: position);
      _playbackStateController.add(_currentState);
    });
    
    // Listen to duration changes
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _currentState = _currentState.copyWith(duration: duration);
        _playbackStateController.add(_currentState);
      }
    });
    
    // Listen to buffered position
    _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
      _bufferedPositionController.add(bufferedPosition);
    });
    
    // Listen to speed changes
    _audioPlayer.speedStream.listen((speed) {
      _speedController.add(speed);
      _currentState = _currentState.copyWith(speed: speed);
      _playbackStateController.add(_currentState);
    });
    
    // Listen to volume changes
    _audioPlayer.volumeStream.listen((volume) {
      _volumeController.add(volume);
      _currentState = _currentState.copyWith(volume: volume);
      _playbackStateController.add(_currentState);
    });
    
    // Handle playback completion
    _audioPlayer.processingStateStream.listen((processingState) {
      if (processingState == ProcessingState.completed) {
        _handleSegmentCompletion();
      }
    });
  }
  
  void _updatePlaybackState(PlayerState playerState) {
    PlaybackStatus status;
    
    if (playerState.playing) {
      status = PlaybackStatus.playing;
    } else {
      switch (playerState.processingState) {
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
          status = PlaybackStatus.paused;
          break;
        case ProcessingState.completed:
          status = PlaybackStatus.completed;
          break;
      }
    }
    
    _currentState = _currentState.copyWith(
      status: status,
      isBuffering: playerState.processingState == ProcessingState.buffering,
    );
    
    _playbackStateController.add(_currentState);
    
    // Update audio service media item
    _updateMediaItem();
  }
  
  void _updateMediaItem() {
    if (_currentBookId == null || _segmentQueue.isEmpty) return;
    
    final currentSegment = _currentSegmentIndex < _segmentQueue.length
        ? _segmentQueue[_currentSegmentIndex]
        : null;
    
    if (currentSegment != null) {
      mediaItem.add(audio_service.MediaItem(
        id: currentSegment.id,
        title: 'Book: $_currentBookId',
        artist: 'Text Reader',
        duration: currentSegment.duration ?? Duration.zero,
        extras: {
          'bookId': _currentBookId,
          'segmentIndex': _currentSegmentIndex,
          'totalSegments': _segmentQueue.length,
        },
      ));
    }
  }
  
  Future<void> loadAudioSegments(
    List<AudioSegment> segments, {
    String? bookId,
    int startIndex = 0,
  }) async {
    try {
      _segmentQueue.clear();
      _segmentQueue.addAll(segments);
      _currentSegmentIndex = startIndex;
      _currentBookId = bookId;
      
      _currentState = _currentState.copyWith(
        currentBookId: bookId,
        currentChunkIndex: startIndex,
        totalChunks: segments.length,
        status: PlaybackStatus.loading,
      );
      
      _playbackStateController.add(_currentState);
      
      if (segments.isNotEmpty && startIndex < segments.length) {
        await _loadSegment(segments[startIndex]);
      }
    } catch (e) {
      _handleError('Failed to load audio segments', e.toString());
    }
  }
  
  Future<void> _loadSegment(AudioSegment segment) async {
    try {
      onSegmentStart?.call(segment.id);
      
      if (segment.audioFilePath != null) {
        // Load from file
        final file = File(segment.audioFilePath!);
        if (await file.exists()) {
          await _audioPlayer.setFilePath(segment.audioFilePath!);
        } else {
          throw Exception('Audio file not found: ${segment.audioFilePath}');
        }
      } else if (segment.audioData != null) {
        // Load from memory
        // Note: just_audio doesn't directly support Uint8List,
        // so we need to save to temp file first
        final tempFile = await _saveTempAudioFile(segment);
        await _audioPlayer.setFilePath(tempFile.path);
      } else {
        throw Exception('No audio data available for segment ${segment.id}');
      }
      
      _updateMediaItem();
    } catch (e) {
      _handleError('Failed to load segment ${segment.id}', e.toString());
    }
  }
  
  Future<File> _saveTempAudioFile(AudioSegment segment) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/temp_audio_${segment.id}.wav');
    await tempFile.writeAsBytes(segment.audioData!);
    return tempFile;
  }
  
  void _handleSegmentCompletion() {
    final currentSegment = _currentSegmentIndex < _segmentQueue.length
        ? _segmentQueue[_currentSegmentIndex]
        : null;
    
    if (currentSegment != null) {
      onSegmentComplete?.call(currentSegment.id);
    }
    
    // Auto-play next segment
    if (_currentSegmentIndex < _segmentQueue.length - 1) {
      playNext();
    } else {
      // All segments completed
      _currentState = _currentState.copyWith(status: PlaybackStatus.completed);
      _playbackStateController.add(_currentState);
    }
  }
  
  void _handleError(String message, String details) {
    print('AudioPlaybackService Error: $message - $details');
    onError?.call(message, details);
    
    _currentState = _currentState.copyWith(
      status: PlaybackStatus.error,
      errorMessage: '$message: $details',
    );
    
    _playbackStateController.add(_currentState);
  }
  
  // Playback controls
  @override
  Future<void> play() async {
    try {
      await _audioPlayer.play();
    } catch (e) {
      _handleError('Failed to play', e.toString());
    }
  }
  
  @override
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      _handleError('Failed to pause', e.toString());
    }
  }
  
  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _currentState = _currentState.copyWith(
        status: PlaybackStatus.idle,
        position: Duration.zero,
      );
      _playbackStateController.add(_currentState);
    } catch (e) {
      _handleError('Failed to stop', e.toString());
    }
  }
  
  @override
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      _handleError('Failed to seek', e.toString());
    }
  }
  
  // BaseAudioHandler overrides with correct signatures
  @override
  Future<void> seekForward(bool begin) async {
    if (begin) {
      await _seekForwardByDuration(const Duration(seconds: 30));
    }
  }
  
  @override
  Future<void> seekBackward(bool begin) async {
    if (begin) {
      await _seekBackwardByDuration(const Duration(seconds: 30));
    }
  }
  
  // Public methods for seeking with custom duration
  Future<void> seekForwardByDuration(Duration offset) async {
    await _seekForwardByDuration(offset);
  }
  
  Future<void> seekBackwardByDuration(Duration offset) async {
    await _seekBackwardByDuration(offset);
  }
  
  // Internal implementation
  Future<void> _seekForwardByDuration(Duration offset) async {
    final newPosition = _audioPlayer.position + offset;
    final duration = _audioPlayer.duration ?? Duration.zero;
    
    if (newPosition < duration) {
      await seek(newPosition);
    } else {
      // Seek to next segment if available
      await playNext();
    }
  }
  
  Future<void> _seekBackwardByDuration(Duration offset) async {
    final newPosition = _audioPlayer.position - offset;
    
    if (newPosition > Duration.zero) {
      await seek(newPosition);
    } else if (_currentSegmentIndex > 0) {
      // Seek to previous segment
      await playPrevious();
    } else {
      await seek(Duration.zero);
    }
  }
  
  Future<void> playNext() async {
    if (_currentSegmentIndex < _segmentQueue.length - 1) {
      _currentSegmentIndex++;
      _currentState = _currentState.copyWith(
        currentChunkIndex: _currentSegmentIndex,
      );
      _playbackStateController.add(_currentState);
      
      await _loadSegment(_segmentQueue[_currentSegmentIndex]);
      await play();
    }
  }
  
  Future<void> playPrevious() async {
    if (_currentSegmentIndex > 0) {
      _currentSegmentIndex--;
      _currentState = _currentState.copyWith(
        currentChunkIndex: _currentSegmentIndex,
      );
      _playbackStateController.add(_currentState);
      
      await _loadSegment(_segmentQueue[_currentSegmentIndex]);
      await play();
    }
  }
  
  Future<void> setSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed);
    } catch (e) {
      _handleError('Failed to set speed', e.toString());
    }
  }
  
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume);
    } catch (e) {
      _handleError('Failed to set volume', e.toString());
    }
  }
  
  // Jump to specific segment
  Future<void> jumpToSegment(int index) async {
    if (index >= 0 && index < _segmentQueue.length) {
      _currentSegmentIndex = index;
      _currentState = _currentState.copyWith(
        currentChunkIndex: index,
      );
      _playbackStateController.add(_currentState);
      
      await _loadSegment(_segmentQueue[index]);
      await play();
    }
  }
  
  // Add segment to queue
  void addSegmentToQueue(AudioSegment segment) {
    _segmentQueue.add(segment);
    _currentState = _currentState.copyWith(
      totalChunks: _segmentQueue.length,
    );
    _playbackStateController.add(_currentState);
  }
  
  // Clear queue
  void clearQueue() {
    _segmentQueue.clear();
    _currentSegmentIndex = 0;
    _currentState = _currentState.copyWith(
      currentChunkIndex: 0,
      totalChunks: 0,
    );
    _playbackStateController.add(_currentState);
  }
  
  // Getters
  Stream<PlaybackState> get playbackStateStream => _playbackStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get bufferedPositionStream => _bufferedPositionController.stream;
  Stream<double> get speedStream => _speedController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  
  PlaybackState get currentState => _currentState;
  AudioPlayer get audioPlayer => _audioPlayer;
  List<AudioSegment> get segmentQueue => List.unmodifiable(_segmentQueue);
  int get currentSegmentIndex => _currentSegmentIndex;
  String? get currentBookId => _currentBookId;
  
  // Background audio support (audio_service)
  @override
  Future<void> skipToNext() => playNext();
  
  @override
  Future<void> skipToPrevious() => playPrevious();
  
  @override
  Future<void> fastForward() => seekForward(true);
  
  @override
  Future<void> rewind() => seekBackward(true);
  
  // setSpeed is already defined above, no need to override
  
  // Clean up
  Future<void> dispose() async {
    await stop();
    await _audioPlayer.dispose();
    await _playbackStateController.close();
    await _positionController.close();
    await _bufferedPositionController.close();
    await _speedController.close();
    await _volumeController.close();
  }
}