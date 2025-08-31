import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:text_reader_app/models/audio_segment.dart';
import 'package:text_reader_app/models/book.dart';
import 'package:text_reader_app/models/playback_state.dart';
import 'package:text_reader_app/services/audio_service.dart';
import 'package:text_reader_app/services/audio_service_init.dart';
import 'package:text_reader_app/services/book_service.dart';
import 'package:text_reader_app/services/storage_service.dart';
import 'package:text_reader_app/services/tts_service.dart';

// Providers
final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

final audioServiceProvider = FutureProvider<AudioPlaybackService>((ref) async {
  final ttsService = ref.watch(ttsServiceProvider);
  return await AudioServiceInit.initialize(ttsService: ttsService);
});

final playerViewModelProvider = 
    StateNotifierProvider<PlayerViewModel, PlayerState>((ref) {
  return PlayerViewModel(ref);
});

// Current book provider
final currentBookProvider = StateProvider<Book?>((ref) => null);

// Playback position provider (updates frequently)
final playbackPositionProvider = StreamProvider<Duration>((ref) async* {
  final audioService = await ref.watch(audioServiceProvider.future);
  yield* audioService.positionStream;
});

// Playback state stream provider
final playbackStateStreamProvider = StreamProvider<PlaybackState>((ref) async* {
  final audioService = await ref.watch(audioServiceProvider.future);
  yield* audioService.playbackStateStream;
});

// Speed provider
final playbackSpeedProvider = StateProvider<double>((ref) => 1.0);

// Volume provider
final playbackVolumeProvider = StateProvider<double>((ref) => 1.0);

// State class
@immutable
class PlayerState {
  final Book? currentBook;
  final PlaybackState playbackState;
  final List<AudioSegment> segments;
  final int currentSegmentIndex;
  final bool isGeneratingAudio;
  final String? error;
  final double progress;
  final Duration totalDuration;
  final bool autoScroll;
  final bool highlightText;
  
  const PlayerState({
    this.currentBook,
    this.playbackState = const PlaybackState(),
    this.segments = const [],
    this.currentSegmentIndex = 0,
    this.isGeneratingAudio = false,
    this.error,
    this.progress = 0.0,
    this.totalDuration = Duration.zero,
    this.autoScroll = true,
    this.highlightText = true,
  });
  
  PlayerState copyWith({
    Book? currentBook,
    PlaybackState? playbackState,
    List<AudioSegment>? segments,
    int? currentSegmentIndex,
    bool? isGeneratingAudio,
    String? error,
    double? progress,
    Duration? totalDuration,
    bool? autoScroll,
    bool? highlightText,
  }) {
    return PlayerState(
      currentBook: currentBook ?? this.currentBook,
      playbackState: playbackState ?? this.playbackState,
      segments: segments ?? this.segments,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      isGeneratingAudio: isGeneratingAudio ?? this.isGeneratingAudio,
      error: error,
      progress: progress ?? this.progress,
      totalDuration: totalDuration ?? this.totalDuration,
      autoScroll: autoScroll ?? this.autoScroll,
      highlightText: highlightText ?? this.highlightText,
    );
  }
  
  bool get isPlaying => playbackState.isPlaying;
  bool get isPaused => playbackState.isPaused;
  bool get isLoading => playbackState.status == PlaybackStatus.loading;
  bool get hasError => playbackState.hasError;
  
  AudioSegment? get currentSegment {
    if (segments.isEmpty || currentSegmentIndex >= segments.length) {
      return null;
    }
    return segments[currentSegmentIndex];
  }
  
  int get currentTextPosition {
    final segment = currentSegment;
    if (segment == null) return 0;
    
    // Calculate position within the segment based on playback position
    final segmentProgress = playbackState.progress;
    final textLength = segment.endPosition - segment.startPosition;
    final positionInSegment = (textLength * segmentProgress).round();
    
    return segment.startPosition + positionInSegment;
  }
}

// ViewModel
class PlayerViewModel extends StateNotifier<PlayerState> {
  final Ref _ref;
  late final TtsService _ttsService;
  late final BookService _bookService;
  late final StorageService _storageService;
  AudioPlaybackService? _audioService;
  
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  Timer? _progressSaveTimer;
  
  PlayerViewModel(this._ref) : super(const PlayerState()) {
    _initialize();
  }
  
  Future<void> _initialize() async {
    try {
      _ttsService = _ref.read(ttsServiceProvider);
      _bookService = _ref.read(bookServiceProvider);
      _storageService = _ref.read(storageServiceProvider);
      
      await _ttsService.initialize();
      await _bookService.initialize();
      await _storageService.initialize();
      
      // Get audio service when available
      _ref.read(audioServiceProvider).whenData((service) {
        _audioService = service;
        _setupAudioServiceListeners();
      });
      
      // Start progress save timer
      _startProgressSaveTimer();
    } catch (e) {
      state = state.copyWith(error: 'Initialization failed: $e');
    }
  }
  
  void _setupAudioServiceListeners() {
    if (_audioService == null) return;
    
    // Listen to playback state changes
    _playbackStateSubscription?.cancel();
    _playbackStateSubscription = _audioService!.playbackStateStream.listen((playbackState) {
      state = state.copyWith(playbackState: playbackState);
      
      // Update current segment index
      if (playbackState.currentChunkIndex != state.currentSegmentIndex) {
        state = state.copyWith(currentSegmentIndex: playbackState.currentChunkIndex);
      }
    });
    
    // Set up callbacks
    _audioService!.onSegmentStart = (segmentId) {
      print('Started playing segment: $segmentId');
    };
    
    _audioService!.onSegmentComplete = (segmentId) {
      print('Completed segment: $segmentId');
      _saveProgress();
    };
    
    _audioService!.onError = (message, details) {
      state = state.copyWith(error: '$message: $details');
    };
  }
  
  void _startProgressSaveTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.isPlaying) {
        _saveProgress();
      }
    });
  }
  
  Future<void> loadBook(Book book) async {
    state = state.copyWith(
      currentBook: book,
      isGeneratingAudio: true,
      error: null,
      segments: [],
    );
    
    // Update current book provider
    _ref.read(currentBookProvider.notifier).state = book;
    
    try {
      // Split text into chunks
      final chunks = TextChunk.splitText(book.content);
      
      // Generate audio segments
      final segments = <AudioSegment>[];
      int processedCount = 0;
      
      for (final chunk in chunks) {
        final segment = await _ttsService.generateAudioSegment(
          chunk.text,
          segmentId: chunk.id,
          startPosition: chunk.startPosition,
          endPosition: chunk.endPosition,
        );
        
        segments.add(segment);
        processedCount++;
        
        // Update progress
        final progress = processedCount / chunks.length;
        state = state.copyWith(
          segments: segments,
          progress: progress,
        );
      }
      
      // Load segments into audio service
      if (_audioService != null && segments.isNotEmpty) {
        await _audioService!.loadAudioSegments(
          segments,
          bookId: book.id,
          startIndex: 0,
        );
      }
      
      // Load last reading position
      final lastPosition = await _storageService.getBookProgress(book.id);
      if (lastPosition != null && lastPosition > 0) {
        await seekToPosition(lastPosition);
      }
      
      state = state.copyWith(
        segments: segments,
        isGeneratingAudio: false,
        progress: 0.0,
      );
    } catch (e) {
      state = state.copyWith(
        isGeneratingAudio: false,
        error: 'Failed to load book: $e',
      );
    }
  }
  
  Future<void> play() async {
    if (_audioService == null) return;
    
    try {
      await _audioService!.play();
    } catch (e) {
      state = state.copyWith(error: 'Failed to play: $e');
    }
  }
  
  Future<void> pause() async {
    if (_audioService == null) return;
    
    try {
      await _audioService!.pause();
      await _saveProgress();
    } catch (e) {
      state = state.copyWith(error: 'Failed to pause: $e');
    }
  }
  
  Future<void> stop() async {
    if (_audioService == null) return;
    
    try {
      await _audioService!.stop();
      await _saveProgress();
    } catch (e) {
      state = state.copyWith(error: 'Failed to stop: $e');
    }
  }
  
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }
  
  Future<void> seekForward() async {
    if (_audioService == null) return;
    
    try {
      await _audioService!.seekForward(const Duration(seconds: 30));
    } catch (e) {
      state = state.copyWith(error: 'Failed to seek forward: $e');
    }
  }
  
  Future<void> seekBackward() async {
    if (_audioService == null) return;
    
    try {
      await _audioService!.seekBackward(const Duration(seconds: 30));
    } catch (e) {
      state = state.copyWith(error: 'Failed to seek backward: $e');
    }
  }
  
  Future<void> seekToPosition(int textPosition) async {
    if (_audioService == null || state.segments.isEmpty) return;
    
    try {
      // Find the segment containing this position
      int segmentIndex = 0;
      for (int i = 0; i < state.segments.length; i++) {
        final segment = state.segments[i];
        if (textPosition >= segment.startPosition && 
            textPosition < segment.endPosition) {
          segmentIndex = i;
          break;
        }
      }
      
      // Jump to the segment
      await _audioService!.jumpToSegment(segmentIndex);
      
      // Calculate position within segment
      final segment = state.segments[segmentIndex];
      final positionInSegment = textPosition - segment.startPosition;
      final segmentLength = segment.endPosition - segment.startPosition;
      final progress = positionInSegment / segmentLength;
      
      if (segment.duration != null) {
        final seekPosition = Duration(
          milliseconds: (segment.duration!.inMilliseconds * progress).round(),
        );
        await _audioService!.seek(seekPosition);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to seek: $e');
    }
  }
  
  Future<void> jumpToSegment(int index) async {
    if (_audioService == null) return;
    
    try {
      await _audioService!.jumpToSegment(index);
    } catch (e) {
      state = state.copyWith(error: 'Failed to jump to segment: $e');
    }
  }
  
  Future<void> setSpeed(double speed) async {
    if (_audioService == null) return;
    
    try {
      await _audioService!.setSpeed(speed);
      await _ttsService.setSpeechRate(speed);
      _ref.read(playbackSpeedProvider.notifier).state = speed;
    } catch (e) {
      state = state.copyWith(error: 'Failed to set speed: $e');
    }
  }
  
  Future<void> setVolume(double volume) async {
    if (_audioService == null) return;
    
    try {
      await _audioService!.setVolume(volume);
      await _ttsService.setVolume(volume);
      _ref.read(playbackVolumeProvider.notifier).state = volume;
    } catch (e) {
      state = state.copyWith(error: 'Failed to set volume: $e');
    }
  }
  
  void toggleAutoScroll() {
    state = state.copyWith(autoScroll: !state.autoScroll);
  }
  
  void toggleHighlightText() {
    state = state.copyWith(highlightText: !state.highlightText);
  }
  
  Future<void> addBookmark() async {
    final book = state.currentBook;
    if (book == null) return;
    
    try {
      final position = state.currentTextPosition;
      await _storageService.addBookmark(book.id, position);
    } catch (e) {
      state = state.copyWith(error: 'Failed to add bookmark: $e');
    }
  }
  
  Future<void> removeBookmark(int position) async {
    final book = state.currentBook;
    if (book == null) return;
    
    try {
      await _storageService.removeBookmark(book.id, position);
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove bookmark: $e');
    }
  }
  
  Future<List<int>> getBookmarks() async {
    final book = state.currentBook;
    if (book == null) return [];
    
    try {
      return await _storageService.getBookmarks(book.id);
    } catch (e) {
      print('Failed to get bookmarks: $e');
      return [];
    }
  }
  
  Future<void> _saveProgress() async {
    final book = state.currentBook;
    if (book == null) return;
    
    try {
      final position = state.currentTextPosition;
      await _storageService.updateBookProgress(book.id, position);
      
      // Update playback state in storage
      await _storageService.savePlaybackState(state.playbackState);
    } catch (e) {
      print('Failed to save progress: $e');
    }
  }
  
  Future<void> regenerateCurrentSegment() async {
    final segment = state.currentSegment;
    if (segment == null || _audioService == null) return;
    
    state = state.copyWith(isGeneratingAudio: true, error: null);
    
    try {
      // Regenerate with different engine or settings
      _ttsService.switchEngine(
        _ttsService.currentEngine == TtsEngine.androidNative
            ? TtsEngine.vibeVoice
            : TtsEngine.androidNative,
      );
      
      final newSegment = await _ttsService.generateAudioSegment(
        segment.text,
        segmentId: segment.id,
        startPosition: segment.startPosition,
        endPosition: segment.endPosition,
      );
      
      // Update segment in list
      final segments = List<AudioSegment>.from(state.segments);
      segments[state.currentSegmentIndex] = newSegment;
      
      state = state.copyWith(
        segments: segments,
        isGeneratingAudio: false,
      );
      
      // Reload in audio service
      await _audioService!.loadAudioSegments(
        segments,
        bookId: state.currentBook?.id,
        startIndex: state.currentSegmentIndex,
      );
    } catch (e) {
      state = state.copyWith(
        isGeneratingAudio: false,
        error: 'Failed to regenerate segment: $e',
      );
    }
  }
  
  @override
  void dispose() {
    _playbackStateSubscription?.cancel();
    _progressSaveTimer?.cancel();
    _saveProgress();
    super.dispose();
  }
}