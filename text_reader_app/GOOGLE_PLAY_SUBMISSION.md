# Google Play Developer Program 申請ガイド

## 事前準備チェックリスト

### 1. Google Developer アカウント
- [ ] Googleアカウントの作成/確認
- [ ] Google Play Console アクセス（https://play.google.com/console）
- [ ] 開発者登録料 $25 の支払い
- [ ] 本人確認書類の提出

### 2. アプリ資産の準備

#### アイコン
- [ ] 高解像度アイコン (512x512px PNG, 32-bit, alpha付き)
- [ ] 適応アイコン (foreground/background レイヤー)

#### スクリーンショット
- [ ] スマートフォン用 (最低2枚、最大8枚)
  - 推奨サイズ: 1080x1920px または 1920x1080px
- [ ] 7インチタブレット用 (オプション)
- [ ] 10インチタブレット用 (オプション)

#### グラフィック素材
- [ ] フィーチャーグラフィック (1024x500px) - 必須
- [ ] プロモーション動画 (YouTube URL) - オプション

### 3. アプリ情報

#### 基本情報
- [ ] アプリ名: VibeVoice Text Reader
- [ ] 簡単な説明 (80文字以内)
- [ ] 詳細な説明 (4000文字以内)
- [ ] カテゴリ: 書籍＆参考書
- [ ] タグ: text-to-speech, reader, tts, audiobook, accessibility

#### コンテンツレーティング
- [ ] IARC質問票の回答
- [ ] 対象年齢の設定

#### 価格と配布
- [ ] 価格設定（無料/有料）
- [ ] 配布国の選択
- [ ] 広告の有無の宣言

### 4. 法的要件

#### プライバシーポリシー
- [ ] プライバシーポリシーの作成
- [ ] ウェブサイトでのホスティング
- [ ] URLの準備

#### 利用規約
- [ ] 利用規約の作成（オプション）
- [ ] ウェブサイトでのホスティング

### 5. 技術要件

#### APK/AAB
- [ ] 署名済みリリースビルド
- [ ] ProGuard/R8による最適化
- [ ] 64ビット対応の確認

#### 権限
- [ ] 必要な権限の宣言と説明
  - インターネットアクセス
  - ストレージアクセス（必要な場合）

### 6. テスト

#### 内部テスト
- [ ] 内部テスターの招待（最大100人）
- [ ] フィードバックの収集
- [ ] バグ修正

#### クローズドベータ
- [ ] ベータテスターの募集
- [ ] テスト期間の設定（推奨: 2週間以上）
- [ ] クラッシュレポートの確認

## 申請手順

### ステップ1: アプリの作成
```bash
1. Google Play Console にログイン
2. 「アプリを作成」をクリック
3. アプリ名、デフォルト言語、アプリ/ゲームの選択
4. 無料/有料の選択
5. 宣言事項への同意
```

### ステップ2: アプリの設定
```bash
1. 「アプリの設定」セクションを完了
   - アプリへのアクセス
   - 広告の有無
   - コンテンツレーティング
   - ターゲット層とコンテンツ
   - ニュースアプリかどうか
   
2. 「メインストアの掲載情報」を入力
   - アプリの詳細
   - グラフィック素材のアップロード
   - カテゴリとタグの選択
```

### ステップ3: リリースの作成
```bash
# Fastlaneを使用した自動アップロード
cd text_reader_app/android
bundle exec fastlane internal

# または手動でのアップロード
1. 「リリース」→「テスト」→「内部テスト」
2. 「新しいリリースを作成」
3. AABファイルをアップロード
4. リリースノートの入力
5. 「確認」→「内部テストとして公開を開始」
```

### ステップ4: 本番リリース
```bash
# 内部テスト完了後
1. 「リリース」→「本番」
2. 「内部テストから本番にプロモート」
3. 段階的なロールアウトの設定（推奨: 10%から開始）
4. 「確認」→「本番として公開を開始」
```

## Fastlaneコマンド

```bash
# 依存関係のインストール
cd text_reader_app/android
bundle install

# 内部テストへのデプロイ
bundle exec fastlane internal

# ベータ版へのプロモート
bundle exec fastlane beta

# 本番へのデプロイ（10%ロールアウト）
bundle exec fastlane production
```

## トラブルシューティング

### よくある問題

1. **AABサイズが大きすぎる**
   - flutter build appbundle --release --tree-shake-icons
   - 不要なアセットの削除

2. **64ビット対応エラー**
   - android/app/build.gradle.kts で ndk.abiFilters の確認

3. **署名エラー**
   - キーストアファイルのパスを確認
   - gradle.properties の設定を確認

4. **APIレベルエラー**
   - targetSdkVersion を最新に更新（現在: 34）

## サポートリンク

- [Google Play Console ヘルプ](https://support.google.com/googleplay/android-developer)
- [Flutter Android リリース](https://docs.flutter.dev/deployment/android)
- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Play Console API](https://developers.google.com/android-publisher)

## 次のステップ

1. ローカルでAPKをビルドしてテスト
   ```bash
   ./scripts/build_local.sh
   ```

2. 署名用キーストアの生成
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias upload
   ```

3. Google Play Consoleでアプリを作成

4. Fastlaneで内部テストにデプロイ

5. フィードバックを収集して改善

6. 本番リリース！