"""
Tests for VibeVoice API endpoints
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import Mock, patch
import json

from main import app, SynthesizeRequest, generate_cache_key


@pytest.fixture
def client():
    """Create test client"""
    return TestClient(app)


@pytest.fixture
def mock_tts_client():
    """Mock Google Cloud TTS client"""
    with patch('main.tts_client') as mock:
        mock_response = Mock()
        mock_response.audio_content = b"fake_audio_data"
        mock.synthesize_speech.return_value = mock_response
        yield mock


@pytest.fixture
def mock_redis_client():
    """Mock Redis client"""
    with patch('main.redis_client') as mock:
        mock.get.return_value = None
        mock.setex.return_value = True
        mock.incr.return_value = 1
        mock.expire.return_value = True
        yield mock


class TestHealthEndpoint:
    def test_health_check(self, client):
        """Test health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "timestamp" in data
        assert "redis" in data
        assert "tts" in data


class TestInfoEndpoint:
    def test_server_info(self, client):
        """Test server info endpoint"""
        response = client.get("/info")
        assert response.status_code == 200
        data = response.json()
        assert data["version"] == "1.0.0"
        assert "ja-JP" in data["supported_languages"]
        assert data["max_text_length"] == 5000
        assert "cache_enabled" in data
        assert data["rate_limit_per_minute"] == 60


class TestVoicesEndpoint:
    @patch('main.tts_client')
    def test_list_voices(self, mock_tts, client):
        """Test list voices endpoint"""
        # Mock voice data
        mock_voice = Mock()
        mock_voice.name = "ja-JP-Standard-A"
        mock_voice.language_codes = ["ja-JP"]
        mock_voice.ssml_gender = 1  # FEMALE
        mock_voice.natural_sample_rate_hertz = 24000
        
        mock_voices = Mock()
        mock_voices.voices = [mock_voice]
        mock_tts.list_voices.return_value = mock_voices
        
        response = client.get("/voices?language_code=ja-JP")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["name"] == "ja-JP-Standard-A"
        assert data[0]["language_codes"] == ["ja-JP"]
        assert data[0]["natural_sample_rate_hertz"] == 24000

    def test_list_voices_no_tts(self, client):
        """Test list voices when TTS is not available"""
        with patch('main.tts_client', None):
            response = client.get("/voices")
            assert response.status_code == 503
            assert "TTS service not available" in response.json()["detail"]


class TestSynthesizeEndpoint:
    @patch('main.tts_client')
    @patch('main.redis_client')
    async def test_synthesize_success(self, mock_redis, mock_tts, client):
        """Test successful synthesis"""
        # Setup mocks
        mock_redis.get.return_value = None
        mock_redis.incr.return_value = 1
        mock_redis.expire.return_value = True
        mock_redis.setex.return_value = True
        
        mock_response = Mock()
        mock_response.audio_content = b"fake_audio_data"
        mock_tts.synthesize_speech.return_value = mock_response
        
        # Make request
        request_data = {
            "text": "テストテキスト",
            "voice": "ja-JP-Standard-A",
            "speed": 1.0,
            "pitch": 0.0,
            "language": "ja-JP"
        }
        
        response = client.post("/synthesize", json=request_data)
        assert response.status_code == 200
        assert response.headers["content-type"] == "audio/mpeg"
        assert response.headers["x-cache"] == "MISS"
        assert response.content == b"fake_audio_data"

    @patch('main.redis_client')
    async def test_synthesize_cache_hit(self, mock_redis, client):
        """Test synthesis with cache hit"""
        # Setup cache hit
        cached_audio = b"cached_audio_data"
        mock_redis.get.return_value = cached_audio
        mock_redis.incr.return_value = 1
        
        request_data = {
            "text": "キャッシュテスト",
            "voice": "ja-JP-Standard-A"
        }
        
        response = client.post("/synthesize", json=request_data)
        assert response.status_code == 200
        assert response.headers["x-cache"] == "HIT"
        assert response.content == cached_audio

    def test_synthesize_invalid_request(self, client):
        """Test synthesis with invalid request"""
        # Empty text
        response = client.post("/synthesize", json={"text": ""})
        assert response.status_code == 422
        
        # Text too long
        long_text = "a" * 6000
        response = client.post("/synthesize", json={"text": long_text})
        assert response.status_code == 422
        
        # Invalid speed
        response = client.post("/synthesize", json={
            "text": "test",
            "speed": 5.0
        })
        assert response.status_code == 422

    @patch('main.redis_client')
    async def test_synthesize_rate_limit(self, mock_redis, client):
        """Test rate limiting"""
        mock_redis.incr.return_value = 61  # Exceed limit
        
        request_data = {"text": "レート制限テスト"}
        response = client.post("/synthesize", json=request_data)
        
        assert response.status_code == 429
        assert "Rate limit exceeded" in response.json()["detail"]
        assert response.headers["retry-after"] == "60"


class TestCacheEndpoints:
    @patch('main.redis_client')
    async def test_cache_stats(self, mock_redis, client):
        """Test cache statistics endpoint"""
        mock_redis.info.return_value = {
            "keyspace_hits": 100,
            "keyspace_misses": 20
        }
        mock_redis.dbsize.return_value = 50
        
        response = client.get("/cache/stats")
        assert response.status_code == 200
        data = response.json()
        assert data["cache_enabled"] == True
        assert data["total_keys"] == 50
        assert data["keyspace_hits"] == 100
        assert data["keyspace_misses"] == 20
        assert data["hit_rate"] == pytest.approx(0.833, rel=0.01)

    @patch('main.redis_client')
    async def test_clear_cache(self, mock_redis, client):
        """Test cache clear endpoint"""
        mock_redis.keys.return_value = [b"audio:key1", b"audio:key2"]
        mock_redis.delete.return_value = 2
        
        response = client.delete("/cache/clear")
        assert response.status_code == 200
        data = response.json()
        assert data["message"] == "Cleared 2 cached items"


class TestUtilities:
    def test_generate_cache_key(self):
        """Test cache key generation"""
        request1 = SynthesizeRequest(
            text="テスト",
            voice="ja-JP-Standard-A",
            speed=1.0,
            pitch=0.0,
            language="ja-JP"
        )
        request2 = SynthesizeRequest(
            text="テスト",
            voice="ja-JP-Standard-A",
            speed=1.0,
            pitch=0.0,
            language="ja-JP"
        )
        request3 = SynthesizeRequest(
            text="違うテキスト",
            voice="ja-JP-Standard-A",
            speed=1.0,
            pitch=0.0,
            language="ja-JP"
        )
        
        key1 = generate_cache_key(request1)
        key2 = generate_cache_key(request2)
        key3 = generate_cache_key(request3)
        
        assert key1 == key2  # Same request should generate same key
        assert key1 != key3  # Different text should generate different key
        assert len(key1) == 64  # SHA256 hex digest length