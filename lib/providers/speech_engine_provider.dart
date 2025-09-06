import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/engines/speech_engine.dart';
import '../services/engines/vibevoice_engine.dart';
import '../services/engines/android_tts_engine.dart';
import 'connectivity_provider.dart';
import 'settings_provider.dart';

/// Engine type enumeration
enum EngineType {
  vibevoice,
  androidTts,
}

/// Speech engine state
class SpeechEngineState {
  final SpeechEngine? engine;
  final EngineType currentType;
  final EngineStatus status;
  final String? errorMessage;
  final DateTime lastSwitched;

  const SpeechEngineState({
    this.engine,
    required this.currentType,
    required this.status,
    this.errorMessage,
    required this.lastSwitched,
  });

  factory SpeechEngineState.initial() {
    return SpeechEngineState(
      engine: null,
      currentType: EngineType.androidTts,
      status: EngineStatus.uninitialized,
      lastSwitched: DateTime.now(),
    );
  }

  SpeechEngineState copyWith({
    SpeechEngine? engine,
    EngineType? currentType,
    EngineStatus? status,
    String? errorMessage,
    DateTime? lastSwitched,
  }) {
    return SpeechEngineState(
      engine: engine ?? this.engine,
      currentType: currentType ?? this.currentType,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSwitched: lastSwitched ?? this.lastSwitched,
    );
  }
}

/// Speech engine manager
class SpeechEngineManager extends StateNotifier<SpeechEngineState> {
  final Ref _ref;
  VibeVoiceEngine? _vibevoiceEngine;
  AndroidTtsEngine? _androidTtsEngine;

  SpeechEngineManager(this._ref) : super(SpeechEngineState.initial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    debugPrint('SpeechEngineManager: Initializing...');
    
    // Initialize Android TTS as fallback
    await _initializeAndroidTts();
    
    // Try to initialize VibeVoice if online
    final isConnected = _ref.read(isConnectedProvider);
    if (isConnected) {
      await _initializeVibeVoice();
    }
    
    // Select appropriate engine
    await _selectEngine();
  }

  Future<void> _initializeAndroidTts() async {
    try {
      debugPrint('SpeechEngineManager: Initializing Android TTS...');
      _androidTtsEngine = AndroidTtsEngine();
      await _androidTtsEngine!.initialize();
      debugPrint('SpeechEngineManager: Android TTS ready');
    } catch (e) {
      debugPrint('SpeechEngineManager: Android TTS initialization failed: $e');
    }
  }

  Future<void> _initializeVibeVoice() async {
    try {
      debugPrint('SpeechEngineManager: Initializing VibeVoice...');
      final settings = _ref.read(settingsProvider);
      _vibevoiceEngine = VibeVoiceEngine(apiUrl: settings.apiUrl);
      await _vibevoiceEngine!.initialize();
      debugPrint('SpeechEngineManager: VibeVoice ready');
    } catch (e) {
      debugPrint('SpeechEngineManager: VibeVoice initialization failed: $e');
      _vibevoiceEngine = null;
    }
  }

  Future<void> _selectEngine() async {
    final settings = _ref.read(settingsProvider);
    final connectivity = _ref.read(connectivityProvider);
    
    // Determine which engine to use
    EngineType targetType;
    SpeechEngine? targetEngine;
    
    if (settings.preferOffline || !connectivity.isConnected) {
      // Use Android TTS
      targetType = EngineType.androidTts;
      targetEngine = _androidTtsEngine;
    } else if (_vibevoiceEngine?.status == EngineStatus.ready) {
      // Use VibeVoice if available
      targetType = EngineType.vibevoice;
      targetEngine = _vibevoiceEngine;
    } else {
      // Fallback to Android TTS
      targetType = EngineType.androidTts;
      targetEngine = _androidTtsEngine;
    }
    
    if (targetEngine != null) {
      state = state.copyWith(
        engine: targetEngine,
        currentType: targetType,
        status: targetEngine.status,
        lastSwitched: DateTime.now(),
      );
      debugPrint('SpeechEngineManager: Selected $targetType engine');
    } else {
      state = state.copyWith(
        status: EngineStatus.error,
        errorMessage: 'No speech engine available',
      );
      debugPrint('SpeechEngineManager: No engine available');
    }
  }

  /// Switch to a specific engine type
  Future<void> switchToEngine(EngineType type) async {
    debugPrint('SpeechEngineManager: Switching to $type...');
    
    switch (type) {
      case EngineType.vibevoice:
        if (_vibevoiceEngine == null) {
          await _initializeVibeVoice();
        }
        if (_vibevoiceEngine?.status == EngineStatus.ready) {
          state = state.copyWith(
            engine: _vibevoiceEngine,
            currentType: EngineType.vibevoice,
            status: _vibevoiceEngine!.status,
            lastSwitched: DateTime.now(),
          );
        }
        break;
        
      case EngineType.androidTts:
        if (_androidTtsEngine == null) {
          await _initializeAndroidTts();
        }
        if (_androidTtsEngine?.status == EngineStatus.ready) {
          state = state.copyWith(
            engine: _androidTtsEngine,
            currentType: EngineType.androidTts,
            status: _androidTtsEngine!.status,
            lastSwitched: DateTime.now(),
          );
        }
        break;
    }
  }

  /// Handle connectivity changes
  void onConnectivityChanged(bool isConnected) {
    final settings = _ref.read(settingsProvider);
    
    if (!settings.autoSwitchEngine) return;
    
    debugPrint('SpeechEngineManager: Connectivity changed - isConnected: $isConnected');
    
    if (isConnected && state.currentType == EngineType.androidTts) {
      // Try switching to VibeVoice
      switchToEngine(EngineType.vibevoice);
    } else if (!isConnected && state.currentType == EngineType.vibevoice) {
      // Switch to Android TTS
      switchToEngine(EngineType.androidTts);
    }
  }

  /// Refresh engine availability
  Future<void> refresh() async {
    debugPrint('SpeechEngineManager: Refreshing...');
    await _selectEngine();
  }

  @override
  void dispose() {
    _vibevoiceEngine?.dispose();
    _androidTtsEngine?.dispose();
    super.dispose();
  }
}

/// Speech engine state provider
final speechEngineStateProvider = 
    StateNotifierProvider<SpeechEngineManager, SpeechEngineState>((ref) {
  final manager = SpeechEngineManager(ref);
  
  // Listen to connectivity changes
  ref.listen<ConnectivityState>(connectivityProvider, (previous, next) {
    if (previous?.isConnected != next.isConnected) {
      manager.onConnectivityChanged(next.isConnected);
    }
  });
  
  return manager;
});

/// Current speech engine provider
final speechEngineProvider = Provider<SpeechEngine?>((ref) {
  return ref.watch(speechEngineStateProvider).engine;
});

/// Current engine type provider
final currentEngineTypeProvider = Provider<EngineType>((ref) {
  return ref.watch(speechEngineStateProvider).currentType;
});

/// Engine status provider
final engineStatusProvider = Provider<EngineStatus>((ref) {
  return ref.watch(speechEngineStateProvider).status;
});