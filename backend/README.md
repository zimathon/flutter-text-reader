# VibeVoice API Server

Text-to-Speech API server for the Flutter Text Reader application.

## Features

- Google Cloud Text-to-Speech integration
- Redis caching for audio data
- Rate limiting
- Multiple voice support (Japanese and English)
- RESTful API with OpenAPI documentation

## Prerequisites

- Python 3.11+
- Redis server
- Google Cloud account with Text-to-Speech API enabled
- Google Cloud service account credentials

## Installation

1. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Configure Google Cloud credentials:
- Create a service account in Google Cloud Console
- Enable Text-to-Speech API
- Download the credentials JSON file
- Set the path in `.env` file

## Running the Server

### Development
```bash
python main.py
```

### Production
```bash
uvicorn main:app --host 0.0.0.0 --port 5000 --workers 4
```

### Docker
```bash
docker build -t vibevoice-api .
docker run -p 5000:5000 --env-file .env vibevoice-api
```

## API Endpoints

- `GET /health` - Health check
- `GET /info` - Server information
- `GET /voices` - List available voices
- `POST /synthesize` - Synthesize text to speech
- `GET /cache/stats` - Cache statistics
- `DELETE /cache` - Clear cache

## API Documentation

Once the server is running, visit:
- Swagger UI: http://localhost:5000/docs
- ReDoc: http://localhost:5000/redoc

## Testing

```bash
# Basic health check
curl http://localhost:5000/health

# Synthesize text
curl -X POST http://localhost:5000/synthesize \
  -H "Content-Type: application/json" \
  -d '{"text": "こんにちは", "voice": "ja-JP-Standard-A"}' \
  --output test.wav
```

## Configuration

See `.env.example` for all available configuration options.

Key settings:
- `MAX_TEXT_LENGTH`: Maximum text length (default: 5000)
- `RATE_LIMIT_PER_MINUTE`: API rate limit (default: 60)
- `CACHE_TTL_HOURS`: Cache expiration time (default: 24)

## Troubleshooting

1. Redis connection error:
   - Ensure Redis is running: `redis-cli ping`
   - Check `REDIS_URL` in `.env`

2. Google Cloud TTS error:
   - Verify credentials file path
   - Check API is enabled in Google Cloud Console
   - Ensure service account has necessary permissions

3. Rate limit exceeded:
   - Wait for rate limit window to reset
   - Adjust `RATE_LIMIT_PER_MINUTE` if needed