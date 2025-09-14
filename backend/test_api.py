import pytest
import json
from unittest.mock import Mock, patch
from fastapi.testclient import TestClient


class TestHealthEndpoint:
    """Test health check endpoint"""
    
    def test_health_check_success(self, app_client):
        """Test successful health check"""
        response = app_client.get("/health")
        assert response.status_code == 200
        
        data = response.json()
        assert data["status"] in ["ok", "degraded"]
        assert "timestamp" in data
        assert "redis_connected" in data
        assert "google_tts_available" in data
    
    def test_health_check_degraded(self, app_client):
        """Test health check when services are degraded"""
        with patch("cache_manager.CacheManager.is_connected", return_value=False):
            response = app_client.get("/health")
            assert response.status_code == 200
            data = response.json()
            assert "redis_connected" in data


class TestInfoEndpoint:
    """Test server info endpoint"""
    
    def test_server_info(self, app_client):
        """Test server information endpoint"""
        response = app_client.get("/info")
        assert response.status_code == 200
        
        data = response.json()
        assert data["version"] == "1.0.0"
        assert "ja-JP" in data["supported_languages"]
        assert "en-US" in data["supported_languages"]
        assert data["max_text_length"] == 5000
        assert data["rate_limit"] == 60
        assert data["cache_ttl_hours"] == 24
        assert isinstance(data["available_voices"], list)


class TestVoicesEndpoint:
    """Test voices listing endpoint"""
    
    def test_list_all_voices(self, app_client):
        """Test listing all available voices"""
        response = app_client.get("/voices")
        assert response.status_code == 200
        
        data = response.json()
        assert "voices" in data
        assert len(data["voices"]) > 0
        
        # Check voice structure
        voice = data["voices"][0]
        assert "id" in voice
        assert "name" in voice
        assert "language_code" in voice
        assert "ssml_gender" in voice
        assert "natural_sample_rate_hertz" in voice
    
    def test_list_voices_by_language(self, app_client):
        """Test listing voices filtered by language"""
        response = app_client.get("/voices?language_code=ja-JP")
        assert response.status_code == 200
        
        data = response.json()
        assert "voices" in data


class TestSynthesizeEndpoint:
    """Test speech synthesis endpoint"""
    
    def test_synthesize_success(self, app_client, sample_synthesis_request):
        """Test successful speech synthesis"""
        response = app_client.post(
            "/synthesize",
            json=sample_synthesis_request
        )
        assert response.status_code == 200
        assert response.headers["content-type"] == "audio/wav"
        assert response.headers["x-cache"] in ["HIT", "MISS"]
        assert len(response.content) > 0
    
    def test_synthesize_with_cache_hit(self, app_client, sample_synthesis_request, mock_redis):
        """Test synthesis with cache hit"""
        # Pre-populate cache
        cache_key = "audio:test_key"
        cached_audio = b"cached_audio_data"
        
        with patch("cache_manager.CacheManager._generate_key", return_value=cache_key):
            with patch("cache_manager.CacheManager.get", return_value=cached_audio):
                response = app_client.post(
                    "/synthesize",
                    json=sample_synthesis_request
                )
                assert response.status_code == 200
                assert response.headers["x-cache"] == "HIT"
                assert response.content == cached_audio
    
    def test_synthesize_empty_text(self, app_client):
        """Test synthesis with empty text"""
        request = {
            "text": "",
            "voice": "ja-JP-Standard-A",
            "speed": 1.0,
            "pitch": 0.0,
            "language": "ja-JP"
        }
        response = app_client.post("/synthesize", json=request)
        assert response.status_code == 422  # Validation error
    
    def test_synthesize_text_too_long(self, app_client):
        """Test synthesis with text exceeding max length"""
        request = {
            "text": "a" * 5001,  # Exceeds max length of 5000
            "voice": "ja-JP-Standard-A",
            "speed": 1.0,
            "pitch": 0.0,
            "language": "ja-JP"
        }
        response = app_client.post("/synthesize", json=request)
        assert response.status_code == 400
        assert "exceeds maximum length" in response.json()["detail"]
    
    def test_synthesize_invalid_voice(self, app_client):
        """Test synthesis with invalid voice"""
        request = {
            "text": "Test text",
            "voice": "invalid-voice",
            "speed": 1.0,
            "pitch": 0.0,
            "language": "ja-JP"
        }
        response = app_client.post("/synthesize", json=request)
        assert response.status_code == 422  # Validation error
    
    def test_synthesize_invalid_speed(self, app_client):
        """Test synthesis with invalid speed"""
        request = {
            "text": "Test text",
            "voice": "ja-JP-Standard-A",
            "speed": 5.0,  # Exceeds max of 4.0
            "pitch": 0.0,
            "language": "ja-JP"
        }
        response = app_client.post("/synthesize", json=request)
        assert response.status_code == 422
    
    @pytest.mark.parametrize("speed,pitch,volume", [
        (0.25, -20.0, -96.0),  # Min values
        (4.0, 20.0, 16.0),      # Max values
        (2.0, 5.0, 3.0),        # Mid values
    ])
    def test_synthesize_with_various_params(self, app_client, speed, pitch, volume):
        """Test synthesis with various parameter values"""
        request = {
            "text": "パラメータテスト",
            "voice": "ja-JP-Standard-A",
            "speed": speed,
            "pitch": pitch,
            "language": "ja-JP",
            "volume_gain_db": volume
        }
        response = app_client.post("/synthesize", json=request)
        assert response.status_code == 200


class TestCacheEndpoints:
    """Test cache management endpoints"""
    
    def test_get_cache_stats(self, app_client):
        """Test getting cache statistics"""
        response = app_client.get("/cache/stats")
        assert response.status_code == 200
        
        data = response.json()
        assert "total_keys" in data
        assert "memory_usage_mb" in data
        assert "hit_rate" in data
        assert "total_hits" in data
        assert "total_misses" in data
    
    def test_clear_cache(self, app_client):
        """Test clearing cache"""
        response = app_client.delete("/cache")
        assert response.status_code == 200
        
        data = response.json()
        assert "message" in data
        assert "Cleared" in data["message"]


class TestRateLimiting:
    """Test rate limiting functionality"""
    
    @pytest.mark.skip(reason="Rate limiting test requires real time delays")
    def test_rate_limit_exceeded(self, app_client, sample_synthesis_request):
        """Test that rate limiting works"""
        # This test would need to make more than 60 requests per minute
        # Skipped in unit tests but can be run in integration tests
        pass


class TestErrorHandling:
    """Test error handling"""
    
    def test_404_not_found(self, app_client):
        """Test 404 error for unknown endpoint"""
        response = app_client.get("/unknown-endpoint")
        assert response.status_code == 404
    
    def test_method_not_allowed(self, app_client):
        """Test 405 error for wrong HTTP method"""
        response = app_client.get("/synthesize")  # Should be POST
        assert response.status_code == 405
    
    def test_tts_engine_failure(self, app_client, sample_synthesis_request):
        """Test handling of TTS engine failure"""
        with patch("tts_engine.TTSEngine.synthesize", return_value=None):
            response = app_client.post(
                "/synthesize",
                json=sample_synthesis_request
            )
            assert response.status_code == 500
            assert "Failed to synthesize audio" in response.json()["detail"]