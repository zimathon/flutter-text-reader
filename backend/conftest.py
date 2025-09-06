import pytest
import os
from typing import Generator
from unittest.mock import Mock, patch
from fastapi.testclient import TestClient
import fakeredis

# Set test environment variables
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = ""
os.environ["REDIS_URL"] = "redis://localhost:6379"
os.environ["RATE_LIMIT_PER_MINUTE"] = "60"
os.environ["CACHE_TTL_HOURS"] = "24"
os.environ["MAX_TEXT_LENGTH"] = "5000"


@pytest.fixture
def mock_redis():
    """Mock Redis client for testing"""
    return fakeredis.FakeRedis(decode_responses=False)


@pytest.fixture
def mock_tts_client():
    """Mock Google Cloud TTS client"""
    mock = Mock()
    mock.synthesize_speech.return_value = Mock(
        audio_content=b"fake_audio_data"
    )
    mock.list_voices.return_value = Mock(
        voices=[
            Mock(
                name="ja-JP-Standard-A",
                language_codes=["ja-JP"],
                ssml_gender=1,  # FEMALE
                natural_sample_rate_hertz=24000
            ),
            Mock(
                name="en-US-Standard-C",
                language_codes=["en-US"],
                ssml_gender=1,  # FEMALE
                natural_sample_rate_hertz=24000
            )
        ]
    )
    return mock


@pytest.fixture
def app_client(mock_redis, mock_tts_client) -> Generator:
    """Create test client with mocked dependencies"""
    with patch("cache_manager.redis.from_url", return_value=mock_redis):
        with patch("tts_engine.texttospeech.TextToSpeechClient", return_value=mock_tts_client):
            # Import here to ensure mocks are in place
            from main import app
            
            # Create test client
            client = TestClient(app)
            yield client


@pytest.fixture
def sample_synthesis_request():
    """Sample synthesis request data"""
    return {
        "text": "こんにちは、テストです",
        "voice": "ja-JP-Standard-A",
        "speed": 1.0,
        "pitch": 0.0,
        "language": "ja-JP",
        "volume_gain_db": 0.0
    }