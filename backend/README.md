# VibeVoice API Server

Google Cloud Text-to-Speech APIを使用した音声合成APIサーバー

## 機能

- テキストから音声（MP3）への変換
- 日本語を含む多言語対応
- Redisベースのキャッシング
- レート制限（1分あたり60リクエスト）
- Docker対応
- 自動スケーリング対応

## セットアップ

### 1. 環境変数の設定

`.env.example`を`.env`にコピーして設定：

```bash
cp .env.example .env
```

主要な設定項目：
- `GOOGLE_APPLICATION_CREDENTIALS`: Google Cloud認証JSONファイルのパス
- `REDIS_URL`: RedisサーバーのURL
- `RATE_LIMIT_PER_MINUTE`: 分あたりのリクエスト制限
- `CACHE_TTL_HOURS`: キャッシュの有効期限（時間）

### 2. Google Cloud認証の設定

1. [Google Cloud Console](https://console.cloud.google.com/)でプロジェクトを作成
2. Text-to-Speech APIを有効化
3. サービスアカウントキーをダウンロード
4. キーファイルを`secrets/gcp-key.json`に配置

### 3. 起動方法

#### Dockerを使用する場合（推奨）

```bash
# ビルドと起動
docker-compose up -d

# ログ確認
docker-compose logs -f api

# 停止
docker-compose down
```

#### ローカル開発環境

```bash
# 仮想環境作成
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 依存関係インストール
pip install -r requirements.txt

# Redis起動（別ターミナル）
redis-server

# サーバー起動
python main.py
```

## APIエンドポイント

### ヘルスチェック
```
GET /health
```

### サーバー情報
```
GET /info
```

### 利用可能な音声リスト
```
GET /voices?language_code=ja-JP
```

### 音声合成
```
POST /synthesize
Content-Type: application/json

{
  "text": "こんにちは",
  "voice": "ja-JP-Standard-A",
  "speed": 1.0,
  "pitch": 0.0,
  "language": "ja-JP"
}
```

### キャッシュ統計
```
GET /cache/stats
```

### キャッシュクリア
```
DELETE /cache/clear
```

## テスト

```bash
# テスト実行
pytest

# カバレッジ付きテスト
pytest --cov=. --cov-report=html
```

## パフォーマンス

- キャッシュヒット時: <10ms
- 新規合成: 200-500ms（テキスト長による）
- 同時接続数: 100+（Nginxでの制御）
- メモリ使用: ~100MB（Redis含む）

## トラブルシューティング

### Google Cloud認証エラー
- 環境変数`GOOGLE_APPLICATION_CREDENTIALS`が正しく設定されているか確認
- サービスアカウントにText-to-Speech APIの権限があるか確認

### Redis接続エラー
- Redisサーバーが起動しているか確認
- `REDIS_URL`が正しいか確認

### レート制限エラー
- 1分あたり60リクエストの制限があります
- `Retry-After`ヘッダーの値だけ待機してください

## ライセンス

MIT