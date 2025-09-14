import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_engine.dart';
import 'vibevoice_engine.dart';
import 'android_tts_engine.dart';

/// Audio engine manager that handles engine selection and fallback
class AudioEngineManager {
  final List<AudioEngine> _engines;
  AudioEngine? _currentEngine;
  final Function(AudioEngine)? onEngineChanged;

  AudioEngineManager({
    List<AudioEngine>? engines,
    this.onEngineChanged,
  }) : _engines = engines ?? [
          VibeVoiceEngine(),
          AndroidTtsEngine(),
        ];

  /// Get current active engine
  AudioEngine? get currentEngine => _currentEngine;

  /// Get all registered engines
  List<AudioEngine> get engines => List.unmodifiable(_engines);

  /// Initialize all engines
  Future<void> initialize() async {
    for (final engine in _engines) {
      try {
        await engine.initialize();
      } catch (e) {
        print('Failed to initialize ${engine.name}: $e');
      }
    }
    
    // Select the first available engine
    await selectBestEngine();
  }

  /// Select the best available engine
  Future<void> selectBestEngine() async {
    for (final engine in _engines) {
      if (await engine.isAvailable) {
        await setEngine(engine);
        return;
      }
    }
    
    // No engine available
    _currentEngine = null;
    throw AudioEngineException('No audio engine available');
  }

  /// Manually set the current engine
  Future<void> setEngine(AudioEngine engine) async {
    if (!_engines.contains(engine)) {
      throw AudioEngineException('Engine not registered');
    }

    if (!await engine.isAvailable) {
      throw AudioEngineException('Engine ${engine.name} is not available');
    }

    _currentEngine = engine;
    onEngineChanged?.call(engine);
  }

  /// Synthesize audio with automatic fallback
  Future<Uint8List> synthesize({
    required String text,
    String? voice,
    double speed = 1.0,
    double pitch = 1.0,
    String? language,
  }) async {
    if (_currentEngine == null) {
      await selectBestEngine();
    }

    if (_currentEngine == null) {
      throw AudioEngineException('No audio engine available');
    }

    try {
      return await _currentEngine!.synthesize(
        text: text,
        voice: voice,
        speed: speed,
        pitch: pitch,
        language: language,
      );
    } catch (e) {
      // Try fallback to next available engine
      final currentIndex = _engines.indexOf(_currentEngine!);
      
      for (int i = currentIndex + 1; i < _engines.length; i++) {
        final fallbackEngine = _engines[i];
        
        if (await fallbackEngine.isAvailable) {
          print('Falling back to ${fallbackEngine.name}');
          await setEngine(fallbackEngine);
          
          try {
            return await fallbackEngine.synthesize(
              text: text,
              voice: voice,
              speed: speed,
              pitch: pitch,
              language: language,
            );
          } catch (fallbackError) {
            continue; // Try next engine
          }
        }
      }
      
      // All engines failed
      throw AudioEngineException('All audio engines failed: $e');
    }
  }

  /// Get available voices from current engine
  Future<List<VoiceInfo>> getAvailableVoices({String? language}) async {
    if (_currentEngine == null) {
      return [];
    }
    
    return await _currentEngine!.getAvailableVoices(language: language);
  }

  /// Dispose all engines
  Future<void> dispose() async {
    for (final engine in _engines) {
      try {
        await engine.dispose();
      } catch (e) {
        print('Failed to dispose ${engine.name}: $e');
      }
    }
    _currentEngine = null;
  }
}

/// Provider for AudioEngineManager
final audioEngineManagerProvider = Provider<AudioEngineManager>((ref) {
  final manager = AudioEngineManager(
    onEngineChanged: (engine) {
      print('Audio engine changed to: ${engine.name}');
    },
  );
  
  ref.onDispose(() {
    manager.dispose();
  });
  
  return manager;
});

/// Provider for current audio engine
final currentAudioEngineProvider = Provider<AudioEngine?>((ref) {
  final manager = ref.watch(audioEngineManagerProvider);
  return manager.currentEngine;
});

/// State notifier for engine selection
class AudioEngineNotifier extends StateNotifier<AudioEngineState> {
  final AudioEngineManager _manager;

  AudioEngineNotifier(this._manager) : super(const AudioEngineState());

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _manager.initialize();
      state = state.copyWith(
        isLoading: false,
        currentEngine: _manager.currentEngine?.name,
        isAvailable: _manager.currentEngine != null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isAvailable: false,
      );
    }
  }

  Future<void> switchEngine(String engineName) async {
    final engine = _manager.engines.firstWhere(
      (e) => e.name == engineName,
      orElse: () => throw AudioEngineException('Engine not found: $engineName'),
    );

    state = state.copyWith(isLoading: true);
    
    try {
      await _manager.setEngine(engine);
      state = state.copyWith(
        isLoading: false,
        currentEngine: engine.name,
        isAvailable: true,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refreshEngineStatus() async {
    if (_manager.currentEngine == null) return;

    final isAvailable = await _manager.currentEngine!.isAvailable;
    
    if (!isAvailable) {
      // Try to find alternative engine
      try {
        await _manager.selectBestEngine();
        state = state.copyWith(
          currentEngine: _manager.currentEngine?.name,
          isAvailable: _manager.currentEngine != null,
        );
      } catch (e) {
        state = state.copyWith(
          isAvailable: false,
          error: 'No audio engine available',
        );
      }
    }
  }
}

/// State for audio engine
class AudioEngineState {
  final bool isLoading;
  final String? currentEngine;
  final bool isAvailable;
  final String? error;

  const AudioEngineState({
    this.isLoading = false,
    this.currentEngine,
    this.isAvailable = false,
    this.error,
  });

  AudioEngineState copyWith({
    bool? isLoading,
    String? currentEngine,
    bool? isAvailable,
    String? error,
  }) {
    return AudioEngineState(
      isLoading: isLoading ?? this.isLoading,
      currentEngine: currentEngine ?? this.currentEngine,
      isAvailable: isAvailable ?? this.isAvailable,
      error: error,
    );
  }
}

/// Provider for audio engine state
final audioEngineStateProvider = 
    StateNotifierProvider<AudioEngineNotifier, AudioEngineState>((ref) {
  final manager = ref.watch(audioEngineManagerProvider);
  return AudioEngineNotifier(manager);
});