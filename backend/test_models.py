import pytest
from pydantic import ValidationError
from models import (
    SynthesizeRequest, HealthResponse, InfoResponse,
    ErrorResponse, VoiceInfo, VoicesResponse, CacheStats,
    VoiceType, LanguageCode
)


class TestSynthesizeRequest:
    """Test SynthesizeRequest model"""
    
    def test_valid_request(self):
        """Test creating a valid synthesis request"""
        request = SynthesizeRequest(
            text="Hello world",
            voice=VoiceType.JA_JP_STANDARD_A,
            speed=1.5,
            pitch=2.0,
            language=LanguageCode.JA_JP,
            volume_gain_db=3.0
        )
        
        assert request.text == "Hello world"
        assert request.voice == VoiceType.JA_JP_STANDARD_A
        assert request.speed == 1.5
        assert request.pitch == 2.0
        assert request.language == LanguageCode.JA_JP
        assert request.volume_gain_db == 3.0
    
    def test_default_values(self):
        """Test default values for optional fields"""
        request = SynthesizeRequest(text="Test")
        
        assert request.text == "Test"
        assert request.voice == VoiceType.JA_JP_STANDARD_A
        assert request.speed == 1.0
        assert request.pitch == 0.0
        assert request.language == LanguageCode.JA_JP
        assert request.volume_gain_db == 0.0
    
    def test_empty_text_validation(self):
        """Test that empty text is rejected"""
        with pytest.raises(ValidationError) as exc_info:
            SynthesizeRequest(text="")
        
        errors = exc_info.value.errors()
        assert any(error["loc"] == ("text",) for error in errors)
    
    def test_text_length_validation(self):
        """Test text length validation"""
        # Max length should be 5000
        long_text = "a" * 5001
        with pytest.raises(ValidationError) as exc_info:
            SynthesizeRequest(text=long_text)
        
        errors = exc_info.value.errors()
        assert any(error["loc"] == ("text",) for error in errors)
    
    def test_speed_validation(self):
        """Test speed parameter validation"""
        # Valid range: 0.25 to 4.0
        with pytest.raises(ValidationError):
            SynthesizeRequest(text="Test", speed=0.1)  # Too slow
        
        with pytest.raises(ValidationError):
            SynthesizeRequest(text="Test", speed=5.0)  # Too fast
        
        # Valid speeds
        SynthesizeRequest(text="Test", speed=0.25)
        SynthesizeRequest(text="Test", speed=4.0)
    
    def test_pitch_validation(self):
        """Test pitch parameter validation"""
        # Valid range: -20.0 to 20.0
        with pytest.raises(ValidationError):
            SynthesizeRequest(text="Test", pitch=-21.0)  # Too low
        
        with pytest.raises(ValidationError):
            SynthesizeRequest(text="Test", pitch=21.0)  # Too high
        
        # Valid pitches
        SynthesizeRequest(text="Test", pitch=-20.0)
        SynthesizeRequest(text="Test", pitch=20.0)
    
    def test_volume_gain_validation(self):
        """Test volume gain validation"""
        # Valid range: -96.0 to 16.0
        with pytest.raises(ValidationError):
            SynthesizeRequest(text="Test", volume_gain_db=-97.0)  # Too quiet
        
        with pytest.raises(ValidationError):
            SynthesizeRequest(text="Test", volume_gain_db=17.0)  # Too loud
        
        # Valid volumes
        SynthesizeRequest(text="Test", volume_gain_db=-96.0)
        SynthesizeRequest(text="Test", volume_gain_db=16.0)


class TestVoiceType:
    """Test VoiceType enum"""
    
    def test_japanese_voices(self):
        """Test Japanese voice types"""
        japanese_voices = [
            VoiceType.JA_JP_STANDARD_A,
            VoiceType.JA_JP_STANDARD_B,
            VoiceType.JA_JP_STANDARD_C,
            VoiceType.JA_JP_STANDARD_D,
            VoiceType.JA_JP_WAVENET_A,
            VoiceType.JA_JP_WAVENET_B,
            VoiceType.JA_JP_WAVENET_C,
            VoiceType.JA_JP_WAVENET_D,
        ]
        
        for voice in japanese_voices:
            assert "ja-JP" in voice.value
    
    def test_english_voices(self):
        """Test English voice types"""
        english_voices = [
            VoiceType.EN_US_STANDARD_A,
            VoiceType.EN_US_STANDARD_B,
            VoiceType.EN_US_STANDARD_C,
            VoiceType.EN_US_STANDARD_D,
        ]
        
        for voice in english_voices:
            assert "en-US" in voice.value


class TestResponseModels:
    """Test response model structures"""
    
    def test_health_response(self):
        """Test HealthResponse model"""
        response = HealthResponse(
            status="ok",
            timestamp="2024-01-01T00:00:00",
            redis_connected=True,
            google_tts_available=True
        )
        
        assert response.status == "ok"
        assert response.redis_connected is True
        assert response.google_tts_available is True
    
    def test_info_response(self):
        """Test InfoResponse model"""
        response = InfoResponse(
            version="1.0.0",
            supported_languages=["ja-JP", "en-US"],
            max_text_length=5000,
            available_voices=["ja-JP-Standard-A"],
            rate_limit=60,
            cache_ttl_hours=24
        )
        
        assert response.version == "1.0.0"
        assert len(response.supported_languages) == 2
        assert response.max_text_length == 5000
    
    def test_error_response(self):
        """Test ErrorResponse model"""
        response = ErrorResponse(
            error="Test error",
            detail="Error details",
            code=400
        )
        
        assert response.error == "Test error"
        assert response.detail == "Error details"
        assert response.code == 400
    
    def test_voice_info(self):
        """Test VoiceInfo model"""
        voice = VoiceInfo(
            id="ja-JP-Standard-A",
            name="Japanese Female A",
            language_code="ja-JP",
            ssml_gender="FEMALE",
            natural_sample_rate_hertz=24000
        )
        
        assert voice.id == "ja-JP-Standard-A"
        assert voice.language_code == "ja-JP"
        assert voice.natural_sample_rate_hertz == 24000
    
    def test_voices_response(self):
        """Test VoicesResponse model"""
        voices = [
            VoiceInfo(
                id="ja-JP-Standard-A",
                name="Japanese Female A",
                language_code="ja-JP",
                ssml_gender="FEMALE",
                natural_sample_rate_hertz=24000
            )
        ]
        
        response = VoicesResponse(voices=voices)
        assert len(response.voices) == 1
        assert response.voices[0].id == "ja-JP-Standard-A"
    
    def test_cache_stats(self):
        """Test CacheStats model"""
        stats = CacheStats(
            total_keys=100,
            memory_usage_mb=50.5,
            hit_rate=85.2,
            total_hits=850,
            total_misses=150
        )
        
        assert stats.total_keys == 100
        assert stats.memory_usage_mb == 50.5
        assert stats.hit_rate == 85.2
        assert stats.total_hits == 850
        assert stats.total_misses == 150