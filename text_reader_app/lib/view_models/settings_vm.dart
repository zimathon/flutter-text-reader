import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:text_reader_app/services/storage_service.dart';
import 'package:text_reader_app/services/tts_service.dart';

// Storage service provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// Settings providers
final settingsViewModelProvider = 
    StateNotifierProvider<SettingsViewModel, SettingsState>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return SettingsViewModel(storageService);
});

// Theme provider
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final settings = ref.watch(settingsViewModelProvider);
  return settings.themeMode;
});

// Font size provider
final fontSizeProvider = StateProvider<double>((ref) {
  final settings = ref.watch(settingsViewModelProvider);
  return settings.fontSize;
});

// Settings state
@immutable
class SettingsState {
  // Display settings
  final ThemeMode themeMode;
  final double fontSize;
  final bool autoScroll;
  final bool highlightCurrentText;
  final double scrollSpeed;
  
  // Audio settings
  final double defaultSpeed;
  final double defaultVolume;
  final TtsEngine preferredEngine;
  final String vibeVoiceUrl;
  final String vibeVoiceApiKey;
  final String vibeVoiceVoiceId;
  final String androidTtsLanguage;
  final double androidTtsPitch;
  
  // App behavior
  final bool autoPlayOnOpen;
  final bool keepScreenOn;
  final bool saveProgressAutomatically;
  final int autoSaveIntervalSeconds;
  final bool showNotifications;
  final bool vibrateOnSegmentChange;
  
  // Advanced settings
  final int maxCacheSize;
  final int chunkSize;
  final bool preloadNextSegment;
  final bool useWifiOnly;
  final bool debugMode;
  
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.fontSize = 16.0,
    this.autoScroll = true,
    this.highlightCurrentText = true,
    this.scrollSpeed = 1.0,
    this.defaultSpeed = 1.0,
    this.defaultVolume = 1.0,
    this.preferredEngine = TtsEngine.androidNative,
    this.vibeVoiceUrl = 'https://microsoft.github.io/VibeVoice/api',
    this.vibeVoiceApiKey = '',
    this.vibeVoiceVoiceId = 'default',
    this.androidTtsLanguage = 'ja-JP',
    this.androidTtsPitch = 1.0,
    this.autoPlayOnOpen = false,
    this.keepScreenOn = true,
    this.saveProgressAutomatically = true,
    this.autoSaveIntervalSeconds = 30,
    this.showNotifications = true,
    this.vibrateOnSegmentChange = false,
    this.maxCacheSize = 50,
    this.chunkSize = 1000,
    this.preloadNextSegment = true,
    this.useWifiOnly = false,
    this.debugMode = false,
  });
  
  SettingsState copyWith({
    ThemeMode? themeMode,
    double? fontSize,
    bool? autoScroll,
    bool? highlightCurrentText,
    double? scrollSpeed,
    double? defaultSpeed,
    double? defaultVolume,
    TtsEngine? preferredEngine,
    String? vibeVoiceUrl,
    String? vibeVoiceApiKey,
    String? vibeVoiceVoiceId,
    String? androidTtsLanguage,
    double? androidTtsPitch,
    bool? autoPlayOnOpen,
    bool? keepScreenOn,
    bool? saveProgressAutomatically,
    int? autoSaveIntervalSeconds,
    bool? showNotifications,
    bool? vibrateOnSegmentChange,
    int? maxCacheSize,
    int? chunkSize,
    bool? preloadNextSegment,
    bool? useWifiOnly,
    bool? debugMode,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      autoScroll: autoScroll ?? this.autoScroll,
      highlightCurrentText: highlightCurrentText ?? this.highlightCurrentText,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      defaultSpeed: defaultSpeed ?? this.defaultSpeed,
      defaultVolume: defaultVolume ?? this.defaultVolume,
      preferredEngine: preferredEngine ?? this.preferredEngine,
      vibeVoiceUrl: vibeVoiceUrl ?? this.vibeVoiceUrl,
      vibeVoiceApiKey: vibeVoiceApiKey ?? this.vibeVoiceApiKey,
      vibeVoiceVoiceId: vibeVoiceVoiceId ?? this.vibeVoiceVoiceId,
      androidTtsLanguage: androidTtsLanguage ?? this.androidTtsLanguage,
      androidTtsPitch: androidTtsPitch ?? this.androidTtsPitch,
      autoPlayOnOpen: autoPlayOnOpen ?? this.autoPlayOnOpen,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      saveProgressAutomatically: saveProgressAutomatically ?? this.saveProgressAutomatically,
      autoSaveIntervalSeconds: autoSaveIntervalSeconds ?? this.autoSaveIntervalSeconds,
      showNotifications: showNotifications ?? this.showNotifications,
      vibrateOnSegmentChange: vibrateOnSegmentChange ?? this.vibrateOnSegmentChange,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      chunkSize: chunkSize ?? this.chunkSize,
      preloadNextSegment: preloadNextSegment ?? this.preloadNextSegment,
      useWifiOnly: useWifiOnly ?? this.useWifiOnly,
      debugMode: debugMode ?? this.debugMode,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'fontSize': fontSize,
      'autoScroll': autoScroll,
      'highlightCurrentText': highlightCurrentText,
      'scrollSpeed': scrollSpeed,
      'defaultSpeed': defaultSpeed,
      'defaultVolume': defaultVolume,
      'preferredEngine': preferredEngine.index,
      'vibeVoiceUrl': vibeVoiceUrl,
      'vibeVoiceApiKey': vibeVoiceApiKey,
      'vibeVoiceVoiceId': vibeVoiceVoiceId,
      'androidTtsLanguage': androidTtsLanguage,
      'androidTtsPitch': androidTtsPitch,
      'autoPlayOnOpen': autoPlayOnOpen,
      'keepScreenOn': keepScreenOn,
      'saveProgressAutomatically': saveProgressAutomatically,
      'autoSaveIntervalSeconds': autoSaveIntervalSeconds,
      'showNotifications': showNotifications,
      'vibrateOnSegmentChange': vibrateOnSegmentChange,
      'maxCacheSize': maxCacheSize,
      'chunkSize': chunkSize,
      'preloadNextSegment': preloadNextSegment,
      'useWifiOnly': useWifiOnly,
      'debugMode': debugMode,
    };
  }
  
  factory SettingsState.fromJson(Map<String, dynamic> json) {
    return SettingsState(
      themeMode: ThemeMode.values[json['themeMode'] ?? 0],
      fontSize: (json['fontSize'] ?? 16.0).toDouble(),
      autoScroll: json['autoScroll'] ?? true,
      highlightCurrentText: json['highlightCurrentText'] ?? true,
      scrollSpeed: (json['scrollSpeed'] ?? 1.0).toDouble(),
      defaultSpeed: (json['defaultSpeed'] ?? 1.0).toDouble(),
      defaultVolume: (json['defaultVolume'] ?? 1.0).toDouble(),
      preferredEngine: TtsEngine.values[json['preferredEngine'] ?? 0],
      vibeVoiceUrl: json['vibeVoiceUrl'] ?? 'https://microsoft.github.io/VibeVoice/api',
      vibeVoiceApiKey: json['vibeVoiceApiKey'] ?? '',
      vibeVoiceVoiceId: json['vibeVoiceVoiceId'] ?? 'default',
      androidTtsLanguage: json['androidTtsLanguage'] ?? 'ja-JP',
      androidTtsPitch: (json['androidTtsPitch'] ?? 1.0).toDouble(),
      autoPlayOnOpen: json['autoPlayOnOpen'] ?? false,
      keepScreenOn: json['keepScreenOn'] ?? true,
      saveProgressAutomatically: json['saveProgressAutomatically'] ?? true,
      autoSaveIntervalSeconds: json['autoSaveIntervalSeconds'] ?? 30,
      showNotifications: json['showNotifications'] ?? true,
      vibrateOnSegmentChange: json['vibrateOnSegmentChange'] ?? false,
      maxCacheSize: json['maxCacheSize'] ?? 50,
      chunkSize: json['chunkSize'] ?? 1000,
      preloadNextSegment: json['preloadNextSegment'] ?? true,
      useWifiOnly: json['useWifiOnly'] ?? false,
      debugMode: json['debugMode'] ?? false,
    );
  }
}

// Theme mode enum
enum ThemeMode { system, light, dark }

// Settings view model
class SettingsViewModel extends StateNotifier<SettingsState> {
  final StorageService _storageService;
  
  SettingsViewModel(this._storageService) : super(const SettingsState()) {
    _loadSettings();
  }
  
  static const String _settingsKey = 'app_settings';
  
  Future<void> _loadSettings() async {
    try {
      await _storageService.initialize();
      final settingsJson = await _storageService.getSettings(_settingsKey);
      
      if (settingsJson != null) {
        state = SettingsState.fromJson(settingsJson);
      }
    } catch (e) {
      print('Failed to load settings: $e');
    }
  }
  
  Future<void> _saveSettings() async {
    try {
      await _storageService.saveSettings(_settingsKey, state.toJson());
    } catch (e) {
      print('Failed to save settings: $e');
    }
  }
  
  // Display settings
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _saveSettings();
  }
  
  Future<void> setFontSize(double size) async {
    if (size >= 12.0 && size <= 32.0) {
      state = state.copyWith(fontSize: size);
      await _saveSettings();
    }
  }
  
  Future<void> toggleAutoScroll() async {
    state = state.copyWith(autoScroll: !state.autoScroll);
    await _saveSettings();
  }
  
  Future<void> toggleHighlightText() async {
    state = state.copyWith(highlightCurrentText: !state.highlightCurrentText);
    await _saveSettings();
  }
  
  Future<void> setScrollSpeed(double speed) async {
    if (speed >= 0.5 && speed <= 3.0) {
      state = state.copyWith(scrollSpeed: speed);
      await _saveSettings();
    }
  }
  
  // Audio settings
  Future<void> setDefaultSpeed(double speed) async {
    if (speed >= 0.5 && speed <= 3.0) {
      state = state.copyWith(defaultSpeed: speed);
      await _saveSettings();
    }
  }
  
  Future<void> setDefaultVolume(double volume) async {
    if (volume >= 0.0 && volume <= 1.0) {
      state = state.copyWith(defaultVolume: volume);
      await _saveSettings();
    }
  }
  
  Future<void> setPreferredEngine(TtsEngine engine) async {
    state = state.copyWith(preferredEngine: engine);
    await _saveSettings();
  }
  
  Future<void> setVibeVoiceUrl(String url) async {
    state = state.copyWith(vibeVoiceUrl: url);
    await _saveSettings();
  }
  
  Future<void> setVibeVoiceApiKey(String apiKey) async {
    state = state.copyWith(vibeVoiceApiKey: apiKey);
    await _saveSettings();
  }
  
  Future<void> setVibeVoiceVoiceId(String voiceId) async {
    state = state.copyWith(vibeVoiceVoiceId: voiceId);
    await _saveSettings();
  }
  
  Future<void> setAndroidTtsLanguage(String language) async {
    state = state.copyWith(androidTtsLanguage: language);
    await _saveSettings();
  }
  
  Future<void> setAndroidTtsPitch(double pitch) async {
    if (pitch >= 0.5 && pitch <= 2.0) {
      state = state.copyWith(androidTtsPitch: pitch);
      await _saveSettings();
    }
  }
  
  // App behavior
  Future<void> toggleAutoPlayOnOpen() async {
    state = state.copyWith(autoPlayOnOpen: !state.autoPlayOnOpen);
    await _saveSettings();
  }
  
  Future<void> toggleKeepScreenOn() async {
    state = state.copyWith(keepScreenOn: !state.keepScreenOn);
    await _saveSettings();
  }
  
  Future<void> toggleSaveProgressAutomatically() async {
    state = state.copyWith(saveProgressAutomatically: !state.saveProgressAutomatically);
    await _saveSettings();
  }
  
  Future<void> setAutoSaveInterval(int seconds) async {
    if (seconds >= 10 && seconds <= 300) {
      state = state.copyWith(autoSaveIntervalSeconds: seconds);
      await _saveSettings();
    }
  }
  
  Future<void> toggleShowNotifications() async {
    state = state.copyWith(showNotifications: !state.showNotifications);
    await _saveSettings();
  }
  
  Future<void> toggleVibrateOnSegmentChange() async {
    state = state.copyWith(vibrateOnSegmentChange: !state.vibrateOnSegmentChange);
    await _saveSettings();
  }
  
  // Advanced settings
  Future<void> setMaxCacheSize(int size) async {
    if (size >= 10 && size <= 200) {
      state = state.copyWith(maxCacheSize: size);
      await _saveSettings();
    }
  }
  
  Future<void> setChunkSize(int size) async {
    if (size >= 500 && size <= 5000) {
      state = state.copyWith(chunkSize: size);
      await _saveSettings();
    }
  }
  
  Future<void> togglePreloadNextSegment() async {
    state = state.copyWith(preloadNextSegment: !state.preloadNextSegment);
    await _saveSettings();
  }
  
  Future<void> toggleUseWifiOnly() async {
    state = state.copyWith(useWifiOnly: !state.useWifiOnly);
    await _saveSettings();
  }
  
  Future<void> toggleDebugMode() async {
    state = state.copyWith(debugMode: !state.debugMode);
    await _saveSettings();
  }
  
  // Reset settings
  Future<void> resetToDefaults() async {
    state = const SettingsState();
    await _saveSettings();
  }
  
  // Export settings
  Map<String, dynamic> exportSettings() {
    return state.toJson();
  }
  
  // Import settings
  Future<void> importSettings(Map<String, dynamic> settings) async {
    try {
      state = SettingsState.fromJson(settings);
      await _saveSettings();
    } catch (e) {
      print('Failed to import settings: $e');
    }
  }
  
  // Validate VibeVoice connection
  Future<bool> testVibeVoiceConnection() async {
    // This would be implemented to test the VibeVoice API connection
    // For now, returning true as placeholder
    return true;
  }
  
  // Get available TTS voices
  Future<List<String>> getAvailableTtsVoices() async {
    // This would query available voices from flutter_tts
    // For now, returning sample voices
    return ['ja-JP', 'en-US', 'en-GB', 'ko-KR', 'zh-CN'];
  }
}