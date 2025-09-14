import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/speech_config.dart';

/// Application settings model
class AppSettings {
  final bool preferOffline;
  final bool autoSwitchEngine;
  final SpeechConfig defaultSpeechConfig;
  final String apiUrl;
  final bool showEngineStatus;
  final bool enableCache;

  const AppSettings({
    this.preferOffline = false,
    this.autoSwitchEngine = true,
    this.defaultSpeechConfig = SpeechConfig.japanese,
    this.apiUrl = 'http://localhost:5000',
    this.showEngineStatus = true,
    this.enableCache = true,
  });

  AppSettings copyWith({
    bool? preferOffline,
    bool? autoSwitchEngine,
    SpeechConfig? defaultSpeechConfig,
    String? apiUrl,
    bool? showEngineStatus,
    bool? enableCache,
  }) {
    return AppSettings(
      preferOffline: preferOffline ?? this.preferOffline,
      autoSwitchEngine: autoSwitchEngine ?? this.autoSwitchEngine,
      defaultSpeechConfig: defaultSpeechConfig ?? this.defaultSpeechConfig,
      apiUrl: apiUrl ?? this.apiUrl,
      showEngineStatus: showEngineStatus ?? this.showEngineStatus,
      enableCache: enableCache ?? this.enableCache,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferOffline': preferOffline,
      'autoSwitchEngine': autoSwitchEngine,
      'defaultSpeechConfig': defaultSpeechConfig.toJson(),
      'apiUrl': apiUrl,
      'showEngineStatus': showEngineStatus,
      'enableCache': enableCache,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      preferOffline: json['preferOffline'] ?? false,
      autoSwitchEngine: json['autoSwitchEngine'] ?? true,
      defaultSpeechConfig: json['defaultSpeechConfig'] != null
          ? SpeechConfig.fromJson(json['defaultSpeechConfig'])
          : SpeechConfig.japanese,
      apiUrl: json['apiUrl'] ?? 'http://localhost:5000',
      showEngineStatus: json['showEngineStatus'] ?? true,
      enableCache: json['enableCache'] ?? true,
    );
  }
}

/// Settings notifier
class SettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;
  static const String _settingsKey = 'app_settings';

  SettingsNotifier(this._prefs) : super(const AppSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    final settingsJson = _prefs.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        final json = Map<String, dynamic>.from(
          Uri.parse(settingsJson).queryParameters,
        );
        state = AppSettings.fromJson(json);
      } catch (e) {
        print('SettingsNotifier: Error loading settings: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      final json = state.toJson();
      final settingsString = Uri(queryParameters: 
        json.map((key, value) => MapEntry(key, value.toString()))
      ).query;
      await _prefs.setString(_settingsKey, settingsString);
    } catch (e) {
      print('SettingsNotifier: Error saving settings: $e');
    }
  }

  void setPreferOffline(bool value) {
    state = state.copyWith(preferOffline: value);
    _saveSettings();
  }

  void setAutoSwitchEngine(bool value) {
    state = state.copyWith(autoSwitchEngine: value);
    _saveSettings();
  }

  void setDefaultSpeechConfig(SpeechConfig config) {
    state = state.copyWith(defaultSpeechConfig: config);
    _saveSettings();
  }

  void setApiUrl(String url) {
    state = state.copyWith(apiUrl: url);
    _saveSettings();
  }

  void setShowEngineStatus(bool value) {
    state = state.copyWith(showEngineStatus: value);
    _saveSettings();
  }

  void setEnableCache(bool value) {
    state = state.copyWith(enableCache: value);
    _saveSettings();
  }

  void resetToDefaults() {
    state = const AppSettings();
    _saveSettings();
  }
}

/// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden');
});

/// Settings provider
final settingsProvider = 
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});