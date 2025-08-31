# Implementation Plan

## プロジェクト初期設定

- [ ] 1. Flutterプロジェクトの初期セットアップ
  - Flutter 3.24+ プロジェクトを作成（flutter create text_reader_app）
  - pubspec.yamlに必要なパッケージを追加（hooks_riverpod, flutter_hooks, just_audio等）
  - AndroidManifest.xmlに必要な権限を追加（INTERNET, FOREGROUND_SERVICE, WAKE_LOCK）
  - プロジェクトのディレクトリ構造を作成（models/, services/, view_models/, views/, shared/）
  - _Requirements: すべての要件の基盤セットアップ_

- [ ] 2. モデルクラスとデータ構造の実装
  - models/book.dartを作成（Book クラスとJSONシリアライズ）
  - models/playback_state.dartを作成（再生状態管理用）
  - models/audio_segment.dartを作成（音声セグメント管理用）
  - 各モデルの単体テストを作成
  - _Requirements: 1, 2, 3, 4の基盤_

## データ永続化とサービス層

- [ ] 3. ストレージサービスの実装
  - services/storage_service.dartを作成（SharedPreferencesラッパー）
  - 書籍データのJSON保存/読み込み機能を実装
  - 読書進捗の保存/復元機能を実装
  - ストレージサービスの単体テストを作成
  - _Requirements: 1, 4_

- [ ] 4. 書籍管理サービスの実装
  - services/book_service.dartを作成
  - テキストファイルのインポート機能を実装（エンコーディング判定含む）
  - 書籍の追加/削除/更新機能を実装
  - ファイルピッカーとの連携を実装
  - 書籍サービスの単体テストを作成
  - _Requirements: 1_

## 音声処理機能

- [ ] 5. TTS基本サービスの実装
  - services/tts_service.dartを作成
  - Android標準TTSの初期実装（flutter_ttsパッケージ使用）
  - テキストから音声生成の基本機能を実装
  - TTSサービスの単体テストを作成
  - _Requirements: 2_

- [ ] 6. VibeVoice API連携の実装
  - services/api_client.dartを作成（Dio設定）
  - VibeVoice APIとの通信機能を実装
  - エラー時のフォールバック処理を実装
  - APIクライアントのモックテストを作成
  - _Requirements: 2_

- [ ] 7. 音声再生サービスの実装
  - services/audio_service.dartを作成
  - just_audioを使用した再生/一時停止機能を実装
  - 30秒早送り/巻き戻し機能を実装
  - 再生速度調整機能を実装
  - 音声サービスの単体テストを作成
  - _Requirements: 3_

## 状態管理層

- [ ] 8. 書籍リストViewModelの実装
  - view_models/book_list_vm.dartを作成（Riverpod Provider）
  - 書籍一覧の取得/更新機能を実装
  - ファイルインポート処理を実装
  - 書籍削除処理を実装
  - ViewModelの単体テストを作成
  - _Requirements: 1_

- [ ] 9. プレイヤーViewModelの実装
  - view_models/player_vm.dartを作成
  - 再生/一時停止/シーク制御を実装
  - TTS生成とキューイング処理を実装
  - 再生状態のストリーム管理を実装
  - ViewModelの単体テストを作成
  - _Requirements: 2, 3_

- [ ] 10. 設定ViewModelの実装
  - view_models/settings_vm.dartを作成
  - 音声設定（速度、音量）の管理を実装
  - 表示設定の管理を実装
  - 設定の永続化処理を実装
  - _Requirements: 5_

## UI実装（基本画面）

- [ ] 11. ホーム画面の実装
  - views/home/home_screen.dartを作成（HookConsumerWidget）
  - 書籍リスト表示機能を実装
  - 検索フィルタリング機能を実装（useTextEditingController使用）
  - views/home/widgets/book_card.dartを作成
  - ホーム画面のWidgetテストを作成
  - _Requirements: 1, 5_

- [ ] 12. リーダー画面の基本実装
  - views/reader/reader_screen.dartを作成
  - テキスト表示エリアを実装（自動スクロール機能付き）
  - 表示モード切り替え機能を実装（useState使用）
  - 読書位置のハイライト機能を実装
  - リーダー画面のWidgetテストを作成
  - _Requirements: 3, 4, 5_

- [ ] 13. 再生コントロールウィジェットの実装
  - views/reader/widgets/playback_controls.dartを作成
  - 再生/一時停止ボタンを実装
  - 30秒早送り/巻き戻しボタンを実装
  - views/reader/widgets/progress_bar.dartを作成（シークバー）
  - コントロールのWidgetテストを作成
  - _Requirements: 3_

## UI実装（追加機能）

- [ ] 14. ファイルインポートUIの実装
  - ファイルピッカーダイアログの実装
  - 複数ファイル選択UIの実装
  - インポート進捗表示の実装
  - エラーハンドリングUIの実装
  - _Requirements: 1_

- [ ] 15. 設定画面の実装
  - views/settings/settings_screen.dartを作成
  - 音声設定UI（速度、音量スライダー）を実装
  - 表示設定UI（ダークモード切り替え）を実装
  - VibeVoice API URLの設定UIを実装
  - _Requirements: 5_

## 高度な機能実装

- [ ] 16. バックグラウンド再生の実装
  - audio_serviceパッケージの設定
  - AudioHandlerクラスの実装
  - 通知コントロールの実装
  - バックグラウンド再生のテストを作成
  - _Requirements: 3_

- [ ] 17. 進捗自動保存機能の実装
  - 定期的な読書位置保存処理を実装（useEffect + Timer）
  - アプリ再起動時の位置復元を実装
  - ブックマーク機能の基本実装
  - 進捗管理のテストを作成
  - _Requirements: 4_

- [ ] 18. テキストチャンク処理の実装
  - 長文テキストの段落分割処理を実装
  - チャンクごとのTTS生成を実装
  - 次チャンクの先読み処理を実装
  - チャンク処理のテストを作成
  - _Requirements: 2_

## 最適化とポリッシュ

- [ ] 19. エラーハンドリングの強化
  - ネットワークエラーの適切な処理を実装
  - TTS生成失敗時のフォールバック強化
  - ユーザーフレンドリーなエラーメッセージの実装
  - エラーハンドリングのテストを作成
  - _Requirements: 2_

- [ ] 20. UIアニメーションとトランジション
  - 画面遷移アニメーションを実装
  - 再生状態変更時のアニメーションを実装（useAnimationController）
  - リスト操作のアニメーションを実装
  - ジェスチャー操作（スワイプ）を実装
  - _Requirements: 5_

## 統合テスト

- [ ] 21. 主要フローの統合テスト
  - ファイルインポート→再生フローのテストを作成
  - 再生制御（再生/一時停止/シーク）のテストを作成
  - 進捗保存→復元フローのテストを作成
  - エンドツーエンドの動作確認テストを作成
  - _Requirements: すべての要件の統合検証_