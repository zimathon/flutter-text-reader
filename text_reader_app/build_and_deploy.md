# ビルドとデプロイメント設定ガイド

## 1. ローカルビルドとテスト

### APKビルド（デバッグ版）
```bash
# デバッグAPKの生成
flutter build apk --debug

# リリースAPKの生成
flutter build apk --release

# APK分割版（より小さいサイズ）
flutter build apk --split-per-abi
```

### AAB（Android App Bundle）ビルド
```bash
# Google Play Store用のAABファイル生成
flutter build appbundle --release
```

### ローカルデバイスでのテスト
```bash
# 接続されているデバイスの確認
flutter devices

# 特定のデバイスでの実行
flutter run -d <device_id>

# リリースモードでの実行
flutter run --release
```

## 2. 署名設定

### キーストアの生成
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### key.propertiesファイルの作成
`android/key.properties`:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path/to/upload-keystore.jks>
```

## 3. Fastlane設定

### インストール
```bash
# Rubyがインストールされていることを確認
ruby --version

# Fastlaneのインストール
sudo gem install fastlane -NV

# またはbundlerを使用
gem install bundler
```

### 初期設定
```bash
cd android
fastlane init
```

### Google Play API設定
1. Google Play Consoleでサービスアカウントを作成
2. JSONキーファイルをダウンロード
3. `android/fastlane/Appfile`に設定を追加

## 4. デプロイメント自動化

### Fastfileの設定例
`android/fastlane/Fastfile`:
```ruby
default_platform(:android)

platform :android do
  desc "Deploy to Google Play Internal Testing"
  lane :internal do
    gradle(
      task: "bundle",
      build_type: "Release"
    )
    upload_to_play_store(
      track: "internal",
      aab: "../build/app/outputs/bundle/release/app-release.aab"
    )
  end

  desc "Deploy to Google Play Beta"
  lane :beta do
    gradle(
      task: "bundle",
      build_type: "Release"
    )
    upload_to_play_store(
      track: "beta",
      aab: "../build/app/outputs/bundle/release/app-release.aab"
    )
  end

  desc "Deploy to Google Play Production"
  lane :production do
    gradle(
      task: "bundle",
      build_type: "Release"
    )
    upload_to_play_store(
      track: "production",
      aab: "../build/app/outputs/bundle/release/app-release.aab"
    )
  end
end
```

## 5. Google Play Developer Program申請

### 必要な準備
1. Google Developer アカウントの作成（$25の登録料）
2. アプリのアイコン（512x512px）
3. スクリーンショット（最低2枚）
4. アプリ説明文（短い説明と詳細説明）
5. プライバシーポリシーURL

### アプリ情報の準備
- アプリ名
- カテゴリ（書籍＆参考書）
- コンテンツレーティング
- 価格設定（無料/有料）

## 6. CI/CD設定（GitHub Actions）

`/.github/workflows/deploy.yml`:
```yaml
name: Deploy to Play Store

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '11'
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Build AAB
        run: flutter build appbundle --release
      
      - name: Setup Fastlane
        run: |
          cd android
          bundle install
      
      - name: Deploy to Play Store
        env:
          PLAY_STORE_JSON_KEY: ${{ secrets.PLAY_STORE_JSON_KEY }}
        run: |
          cd android
          fastlane production
```

## 7. ローカル検証チェックリスト

- [ ] APKのインストールと起動確認
- [ ] 全機能の動作テスト
- [ ] 異なるAndroidバージョンでのテスト
- [ ] パフォーマンステスト
- [ ] メモリリークの確認
- [ ] ネットワークエラー処理の確認