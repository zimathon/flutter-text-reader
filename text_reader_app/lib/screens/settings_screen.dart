import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:text_reader_app/services/tts_service.dart';
import 'package:text_reader_app/view_models/settings_vm.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final settingsViewModel = ref.read(settingsViewModelProvider.notifier);
    final tabController = useTabController(initialLength: 4);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        bottom: TabBar(
          controller: tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '表示'),
            Tab(text: '音声'),
            Tab(text: 'アプリ'),
            Tab(text: '詳細'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          // Display settings tab
          _DisplaySettingsTab(
            settings: settings,
            viewModel: settingsViewModel,
          ),
          // Audio settings tab
          _AudioSettingsTab(
            settings: settings,
            viewModel: settingsViewModel,
          ),
          // App behavior tab
          _AppBehaviorTab(
            settings: settings,
            viewModel: settingsViewModel,
          ),
          // Advanced settings tab
          _AdvancedSettingsTab(
            settings: settings,
            viewModel: settingsViewModel,
          ),
        ],
      ),
    );
  }
}

class _DisplaySettingsTab extends StatelessWidget {
  final SettingsState settings;
  final SettingsViewModel viewModel;

  const _DisplaySettingsTab({
    required this.settings,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsSection(
          title: 'テーマ',
          children: [
            ListTile(
              title: const Text('テーマモード'),
              subtitle: Text(_getThemeModeLabel(settings.themeMode)),
              leading: const Icon(Icons.palette),
              onTap: () => _showThemeDialog(context),
            ),
          ],
        ),
        _SettingsSection(
          title: 'テキスト表示',
          children: [
            ListTile(
              title: const Text('フォントサイズ'),
              subtitle: Text('${settings.fontSize.toStringAsFixed(0)} pt'),
              leading: const Icon(Icons.text_fields),
            ),
            Slider(
              value: settings.fontSize,
              min: 12,
              max: 32,
              divisions: 20,
              label: '${settings.fontSize.toStringAsFixed(0)} pt',
              onChanged: (value) => viewModel.setFontSize(value),
            ),
            SwitchListTile(
              title: const Text('自動スクロール'),
              subtitle: const Text('読み上げ位置に自動でスクロール'),
              secondary: const Icon(Icons.swap_vert),
              value: settings.autoScroll,
              onChanged: (_) => viewModel.toggleAutoScroll(),
            ),
            SwitchListTile(
              title: const Text('テキストハイライト'),
              subtitle: const Text('現在読んでいる部分を強調表示'),
              secondary: const Icon(Icons.highlight),
              value: settings.highlightCurrentText,
              onChanged: (_) => viewModel.toggleHighlightText(),
            ),
            ListTile(
              title: const Text('スクロール速度'),
              subtitle: Text('${settings.scrollSpeed.toStringAsFixed(1)}x'),
              leading: const Icon(Icons.speed),
            ),
            Slider(
              value: settings.scrollSpeed,
              min: 0.5,
              max: 3.0,
              divisions: 10,
              label: '${settings.scrollSpeed.toStringAsFixed(1)}x',
              onChanged: (value) => viewModel.setScrollSpeed(value),
            ),
          ],
        ),
      ],
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'システム設定に従う';
      case ThemeMode.light:
        return 'ライトモード';
      case ThemeMode.dark:
        return 'ダークモード';
    }
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テーマモードを選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('システム設定に従う'),
              value: ThemeMode.system,
              groupValue: settings.themeMode,
              onChanged: (value) {
                viewModel.setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('ライトモード'),
              value: ThemeMode.light,
              groupValue: settings.themeMode,
              onChanged: (value) {
                viewModel.setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('ダークモード'),
              value: ThemeMode.dark,
              groupValue: settings.themeMode,
              onChanged: (value) {
                viewModel.setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioSettingsTab extends StatelessWidget {
  final SettingsState settings;
  final SettingsViewModel viewModel;

  const _AudioSettingsTab({
    required this.settings,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsSection(
          title: '基本設定',
          children: [
            ListTile(
              title: const Text('デフォルト再生速度'),
              subtitle: Text('${settings.defaultSpeed.toStringAsFixed(1)}x'),
              leading: const Icon(Icons.speed),
            ),
            Slider(
              value: settings.defaultSpeed,
              min: 0.5,
              max: 3.0,
              divisions: 10,
              label: '${settings.defaultSpeed.toStringAsFixed(1)}x',
              onChanged: (value) => viewModel.setDefaultSpeed(value),
            ),
            ListTile(
              title: const Text('デフォルト音量'),
              subtitle: Text('${(settings.defaultVolume * 100).toStringAsFixed(0)}%'),
              leading: const Icon(Icons.volume_up),
            ),
            Slider(
              value: settings.defaultVolume,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(settings.defaultVolume * 100).toStringAsFixed(0)}%',
              onChanged: (value) => viewModel.setDefaultVolume(value),
            ),
          ],
        ),
        _SettingsSection(
          title: 'TTSエンジン',
          children: [
            ListTile(
              title: const Text('優先エンジン'),
              subtitle: Text(_getEngineLabel(settings.preferredEngine)),
              leading: const Icon(Icons.record_voice_over),
              onTap: () => _showEngineDialog(context),
            ),
          ],
        ),
        if (settings.preferredEngine == TtsEngine.vibeVoice) ...[
          _SettingsSection(
            title: 'VibeVoice設定',
            children: [
              ListTile(
                title: const Text('API URL'),
                subtitle: Text(settings.vibeVoiceUrl),
                leading: const Icon(Icons.link),
                onTap: () => _showTextInputDialog(
                  context,
                  'VibeVoice API URL',
                  settings.vibeVoiceUrl,
                  (value) => viewModel.setVibeVoiceUrl(value),
                ),
              ),
              ListTile(
                title: const Text('APIキー'),
                subtitle: Text(settings.vibeVoiceApiKey.isEmpty
                    ? '未設定'
                    : '設定済み'),
                leading: const Icon(Icons.key),
                onTap: () => _showTextInputDialog(
                  context,
                  'VibeVoice APIキー',
                  settings.vibeVoiceApiKey,
                  (value) => viewModel.setVibeVoiceApiKey(value),
                  obscureText: true,
                ),
              ),
              ListTile(
                title: const Text('音声ID'),
                subtitle: Text(settings.vibeVoiceVoiceId),
                leading: const Icon(Icons.person),
                onTap: () => _showTextInputDialog(
                  context,
                  'VibeVoice音声ID',
                  settings.vibeVoiceVoiceId,
                  (value) => viewModel.setVibeVoiceVoiceId(value),
                ),
              ),
              ListTile(
                title: const Text('接続テスト'),
                leading: const Icon(Icons.network_check),
                onTap: () async {
                  final result = await viewModel.testVibeVoiceConnection();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result
                            ? '接続成功'
                            : '接続失敗'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
        if (settings.preferredEngine == TtsEngine.androidNative) ...[
          _SettingsSection(
            title: 'Android TTS設定',
            children: [
              ListTile(
                title: const Text('言語'),
                subtitle: Text(settings.androidTtsLanguage),
                leading: const Icon(Icons.language),
                onTap: () => _showLanguageDialog(context),
              ),
              ListTile(
                title: const Text('ピッチ'),
                subtitle: Text('${settings.androidTtsPitch.toStringAsFixed(1)}'),
                leading: const Icon(Icons.tune),
              ),
              Slider(
                value: settings.androidTtsPitch,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                label: settings.androidTtsPitch.toStringAsFixed(1),
                onChanged: (value) => viewModel.setAndroidTtsPitch(value),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _getEngineLabel(TtsEngine engine) {
    switch (engine) {
      case TtsEngine.androidNative:
        return 'Android TTS';
      case TtsEngine.vibeVoice:
        return 'VibeVoice';
    }
  }

  void _showEngineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TTSエンジンを選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<TtsEngine>(
              title: const Text('Android TTS'),
              subtitle: const Text('デバイス内蔵の音声合成'),
              value: TtsEngine.androidNative,
              groupValue: settings.preferredEngine,
              onChanged: (value) {
                viewModel.setPreferredEngine(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<TtsEngine>(
              title: const Text('VibeVoice'),
              subtitle: const Text('高品質なオンライン音声合成'),
              value: TtsEngine.vibeVoice,
              groupValue: settings.preferredEngine,
              onChanged: (value) {
                viewModel.setPreferredEngine(value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) async {
    final languages = await viewModel.getAvailableTtsVoices();
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('言語を選択'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((lang) => 
              RadioListTile<String>(
                title: Text(lang),
                value: lang,
                groupValue: settings.androidTtsLanguage,
                onChanged: (value) {
                  viewModel.setAndroidTtsLanguage(value!);
                  Navigator.pop(context);
                },
              ),
            ).toList(),
          ),
        ),
      ),
    );
  }

  void _showTextInputDialog(
    BuildContext context,
    String title,
    String initialValue,
    ValueChanged<String> onSave, {
    bool obscureText = false,
  }) {
    final controller = TextEditingController(text: initialValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    
    // Clean up controller when dialog closes
    Future.delayed(const Duration(seconds: 1), () {
      controller.dispose();
    });
  }
}

class _AppBehaviorTab extends StatelessWidget {
  final SettingsState settings;
  final SettingsViewModel viewModel;

  const _AppBehaviorTab({
    required this.settings,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsSection(
          title: '再生動作',
          children: [
            SwitchListTile(
              title: const Text('開いたら自動再生'),
              subtitle: const Text('書籍を開いたときに自動で再生を開始'),
              secondary: const Icon(Icons.play_circle_outline),
              value: settings.autoPlayOnOpen,
              onChanged: (_) => viewModel.toggleAutoPlayOnOpen(),
            ),
            SwitchListTile(
              title: const Text('画面を常時点灯'),
              subtitle: const Text('再生中は画面をオフにしない'),
              secondary: const Icon(Icons.brightness_high),
              value: settings.keepScreenOn,
              onChanged: (_) => viewModel.toggleKeepScreenOn(),
            ),
            SwitchListTile(
              title: const Text('振動フィードバック'),
              subtitle: const Text('セグメント切り替え時に振動'),
              secondary: const Icon(Icons.vibration),
              value: settings.vibrateOnSegmentChange,
              onChanged: (_) => viewModel.toggleVibrateOnSegmentChange(),
            ),
          ],
        ),
        _SettingsSection(
          title: '進捗保存',
          children: [
            SwitchListTile(
              title: const Text('自動保存'),
              subtitle: const Text('読書進捗を自動的に保存'),
              secondary: const Icon(Icons.save),
              value: settings.saveProgressAutomatically,
              onChanged: (_) => viewModel.toggleSaveProgressAutomatically(),
            ),
            ListTile(
              title: const Text('保存間隔'),
              subtitle: Text('${settings.autoSaveIntervalSeconds}秒'),
              leading: const Icon(Icons.timer),
              enabled: settings.saveProgressAutomatically,
            ),
            Slider(
              value: settings.autoSaveIntervalSeconds.toDouble(),
              min: 10,
              max: 300,
              divisions: 29,
              label: '${settings.autoSaveIntervalSeconds}秒',
              onChanged: settings.saveProgressAutomatically
                  ? (value) => viewModel.setAutoSaveInterval(value.toInt())
                  : null,
            ),
          ],
        ),
        _SettingsSection(
          title: '通知',
          children: [
            SwitchListTile(
              title: const Text('通知を表示'),
              subtitle: const Text('再生中の通知を表示'),
              secondary: const Icon(Icons.notifications),
              value: settings.showNotifications,
              onChanged: (_) => viewModel.toggleShowNotifications(),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdvancedSettingsTab extends StatelessWidget {
  final SettingsState settings;
  final SettingsViewModel viewModel;

  const _AdvancedSettingsTab({
    required this.settings,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsSection(
          title: 'パフォーマンス',
          children: [
            ListTile(
              title: const Text('キャッシュサイズ'),
              subtitle: Text('最大${settings.maxCacheSize}個'),
              leading: const Icon(Icons.storage),
            ),
            Slider(
              value: settings.maxCacheSize.toDouble(),
              min: 10,
              max: 200,
              divisions: 19,
              label: '${settings.maxCacheSize}個',
              onChanged: (value) => viewModel.setMaxCacheSize(value.toInt()),
            ),
            ListTile(
              title: const Text('チャンクサイズ'),
              subtitle: Text('${settings.chunkSize}文字'),
              leading: const Icon(Icons.segment),
            ),
            Slider(
              value: settings.chunkSize.toDouble(),
              min: 500,
              max: 5000,
              divisions: 9,
              label: '${settings.chunkSize}文字',
              onChanged: (value) => viewModel.setChunkSize(value.toInt()),
            ),
            SwitchListTile(
              title: const Text('次のセグメントを事前読み込み'),
              subtitle: const Text('スムーズな再生のため事前に音声を生成'),
              secondary: const Icon(Icons.cloud_download),
              value: settings.preloadNextSegment,
              onChanged: (_) => viewModel.togglePreloadNextSegment(),
            ),
          ],
        ),
        _SettingsSection(
          title: 'ネットワーク',
          children: [
            SwitchListTile(
              title: const Text('Wi-Fiのみ使用'),
              subtitle: const Text('VibeVoice使用時はWi-Fi接続時のみ'),
              secondary: const Icon(Icons.wifi),
              value: settings.useWifiOnly,
              onChanged: (_) => viewModel.toggleUseWifiOnly(),
            ),
          ],
        ),
        _SettingsSection(
          title: '開発者オプション',
          children: [
            SwitchListTile(
              title: const Text('デバッグモード'),
              subtitle: const Text('詳細なログを表示'),
              secondary: const Icon(Icons.bug_report),
              value: settings.debugMode,
              onChanged: (_) => viewModel.toggleDebugMode(),
            ),
            ListTile(
              title: const Text('設定をリセット'),
              leading: const Icon(Icons.restore),
              onTap: () => _showResetDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設定をリセット'),
        content: const Text('すべての設定をデフォルト値に戻しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              viewModel.resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('設定をリセットしました'),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('リセット'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 8),
      ],
    );
  }
}