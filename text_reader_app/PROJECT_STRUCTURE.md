# Flutter Text Reader App - プロジェクト構成説明書

## 概要

本アプリケーションは、テキストファイルを音声で読み上げるFlutterベースのAndroidアプリケーションです。VibeVoice APIと Android Native TTSをサポートし、オフライン・オンライン両方での動作が可能です。

## 技術スタック

- **フレームワーク**: Flutter 3.27.3
- **言語**: Dart
- **状態管理**: Riverpod + Flutter Hooks
- **アーキテクチャ**: MVVM (Model-View-ViewModel)
- **音声合成**: 
  - VibeVoice API (オンライン高品質)
  - Android Native TTS (オフライン)
- **データ永続化**: SharedPreferences
- **ファイル管理**: path_provider, file_picker

## プロジェクト構造

```
text_reader_app/
├── lib/
│   ├── main.dart                 # アプリケーションエントリーポイント
│   ├── models/                   # データモデル
│   │   ├── audio_segment.dart    # 音声セグメントとテキストチャンク
│   │   ├── book.dart             # 書籍データモデル
│   │   └── playback_state.dart   # 再生状態管理
│   ├── services/                 # ビジネスロジック層
│   │   ├── api_client.dart       # HTTP通信基盤
│   │   ├── audio_service.dart    # 音声再生サービス
│   │   ├── audio_service_init.dart # 音声サービス初期化
│   │   ├── book_service.dart     # 書籍管理サービス
│   │   ├── storage_service.dart  # ローカルストレージ
│   │   ├── tts_service.dart      # TTS統合インターフェース
│   │   └── vibevoice_service.dart # VibeVoice API実装
│   ├── view_models/              # ViewModelレイヤー
│   │   ├── book_list_vm.dart     # 書籍リスト管理
│   │   ├── player_vm.dart        # 再生制御
│   │   └── settings_vm.dart      # 設定管理
│   ├── screens/                  # 画面コンポーネント
│   │   ├── home_screen.dart      # ホーム画面
│   │   ├── reader_screen.dart    # リーダー画面
│   │   └── settings_screen.dart  # 設定画面
│   ├── widgets/                  # 再利用可能なウィジェット
│   │   ├── book_list_item.dart   # 書籍リストアイテム
│   │   ├── chapter_drawer.dart   # チャプター選択
│   │   ├── empty_state.dart      # 空状態表示
│   │   ├── playback_controls.dart # 再生コントロール
│   │   ├── search_bar.dart       # 検索バー
│   │   └── text_display.dart     # テキスト表示
│   └── utils/                    # ユーティリティ
│       ├── animations.dart       # アニメーション
│       ├── error_handler.dart    # エラーハンドリング
│       └── formatting.dart       # フォーマッター
├── test/                         # テストファイル
│   ├── integration/              # 統合テスト
│   ├── services/                 # サービステスト
│   └── widget_test.dart          # ウィジェットテスト
├── android/                      # Android固有設定
├── ios/                          # iOS固有設定（未使用）
├── pubspec.yaml                  # 依存関係定義
└── README.md                     # プロジェクト説明

```

## 主要コンポーネント説明

### 1. Models (データモデル層)

#### Book Model (`models/book.dart`)
- 書籍情報を管理するデータクラス
- タイトル、著者、コンテンツ、読書進捗を保持
- JSON シリアライゼーション対応

#### AudioSegment Model (`models/audio_segment.dart`)
- 音声セグメントと対応するテキスト範囲を管理
- テキストチャンキング機能（日本語対応）
- キャッシュ管理サポート

#### PlaybackState Model (`models/playback_state.dart`)
- 再生状態（再生中、一時停止、停止等）
- 再生位置、速度、音量情報
- エラー状態管理

### 2. Services (サービス層)

#### AudioService (`services/audio_service.dart`)
- **責任**: 音声再生の制御
- **機能**:
  - just_audio を使用した音声再生
  - バックグラウンド再生サポート
  - セグメントキューイング
  - 再生位置管理

#### TtsService (`services/tts_service.dart`)
- **責任**: テキスト音声変換の抽象化
- **機能**:
  - VibeVoice と Android TTS の切り替え
  - 音声生成とキャッシング
  - エンジン設定管理

#### BookService (`services/book_service.dart`)
- **責任**: 書籍ファイルの管理
- **機能**:
  - ファイルインポート（txt, md, rtf）
  - エンコーディング検出（UTF-8, Shift-JIS, EUC-JP）
  - ファイル読み書き

#### StorageService (`services/storage_service.dart`)
- **責任**: ローカルデータ永続化
- **機能**:
  - 書籍リスト保存
  - 読書進捗管理
  - 設定保存
  - ブックマーク管理

### 3. ViewModels (ビューモデル層)

#### PlayerViewModel (`view_models/player_vm.dart`)
- **責任**: 再生ロジックと状態管理
- **Provider**: `playerViewModelProvider`
- **主要機能**:
  - 書籍の読み込みと音声生成
  - 再生制御（再生、一時停止、シーク）
  - 進捗自動保存

#### BookListViewModel (`view_models/book_list_vm.dart`)
- **責任**: 書籍リスト管理
- **Provider**: `bookListViewModelProvider`
- **主要機能**:
  - 書籍のインポート/削除
  - 検索とソート
  - 統計情報生成

#### SettingsViewModel (`view_models/settings_vm.dart`)
- **責任**: アプリ設定管理
- **Provider**: `settingsViewModelProvider`
- **主要機能**:
  - テーマ設定
  - 音声設定（速度、音量、エンジン）
  - 自動再生設定

### 4. Screens (画面層)

#### HomeScreen (`screens/home_screen.dart`)
- 書籍リスト表示
- 検索・ソート機能
- ファイルインポート
- 統計情報表示

#### ReaderScreen (`screens/reader_screen.dart`)
- テキスト表示（自動スクロール対応）
- 再生コントロール
- チャプター選択
- ブックマーク機能

#### SettingsScreen (`screens/settings_screen.dart`)
- テーマ設定（ライト/ダーク/システム）
- 音声エンジン設定
- 再生設定（速度、音量）
- VibeVoice API設定

### 5. Widgets (ウィジェット層)

#### PlaybackControls (`widgets/playback_controls.dart`)
- 再生/一時停止ボタン
- 30秒早送り/巻き戻し
- 速度・音量調整
- 進捗バー

#### TextDisplay (`widgets/text_display.dart`)
- テキスト表示とハイライト
- 自動スクロール
- フォントサイズ調整
- 現在位置追跡

## 主要機能

### 1. ファイルインポート
- 対応形式: `.txt`, `.md`, `.rtf`
- エンコーディング自動検出
- 複数ファイル同時インポート

### 2. 音声読み上げ
- **VibeVoice API**: 高品質音声合成（オンライン）
- **Android TTS**: オフライン読み上げ
- 自動フォールバック機能

### 3. 再生制御
- 再生/一時停止
- 30秒早送り/巻き戻し
- 速度調整（0.5x - 3.0x）
- 音量調整

### 4. テキスト管理
- 日本語対応のテキストチャンキング
- 文章境界を考慮した分割
- オーバーラップによるコンテキスト保持

### 5. 進捗管理
- 自動進捗保存（30秒ごと）
- ブックマーク機能
- 読書統計

### 6. UI/UX
- Material Design 3準拠
- ダークモード対応
- アニメーション効果
- エラーハンドリング

## ビルドと実行

### 必要環境
- Flutter SDK 3.27.3以上
- Dart SDK 3.6.0以上
- Android Studio / VS Code
- Android SDK (API Level 21以上)

### ビルド手順

```bash
# 依存関係の取得
flutter pub get

# デバッグビルド
flutter build apk --debug

# リリースビルド
flutter build apk --release

# 実行
flutter run
```

### テスト実行

```bash
# 全テスト実行
flutter test

# 統合テスト
flutter test test/integration/

# カバレッジ付きテスト
flutter test --coverage
```

## 設定とカスタマイズ

### VibeVoice API設定
1. 設定画面を開く
2. 「音声設定」→「VibeVoice設定」
3. APIエンドポイントとAPIキーを入力

### テーマカスタマイズ
- `lib/main.dart` の ThemeData を編集
- Material 3 カラースキームを使用

### 言語サポート
- 現在は日本語と英語をサポート
- `lib/services/tts_service.dart` で言語設定可能

## トラブルシューティング

### ビルドエラー
- `flutter clean` を実行
- `flutter pub cache repair` を実行
- Android Gradle プラグインの更新確認

### 音声が再生されない
- Android TTSがインストールされているか確認
- インターネット接続を確認（VibeVoice使用時）
- 設定で音声エンジンを切り替える

### テキストが正しく表示されない
- ファイルのエンコーディングを確認
- 対応エンコーディング: UTF-8, Shift-JIS, EUC-JP

## ライセンスと依存関係

主要な依存パッケージ:
- `hooks_riverpod`: 状態管理
- `flutter_hooks`: React Hooks風のステート管理
- `just_audio`: 音声再生
- `audio_service`: バックグラウンド再生
- `flutter_tts`: ネイティブTTS
- `file_picker`: ファイル選択
- `shared_preferences`: ローカルストレージ

詳細は `pubspec.yaml` を参照してください。

## 今後の改善点

1. **パフォーマンス最適化**
   - 大容量ファイルの分割読み込み
   - メモリ使用量の最適化

2. **機能拡張**
   - PDF対応
   - クラウド同期
   - 複数言語対応の拡充

3. **UI/UX改善**
   - タブレット対応レイアウト
   - ジェスチャー操作
   - カスタムテーマ

4. **テスト強化**
   - E2Eテストの追加
   - パフォーマンステスト
   - アクセシビリティテスト