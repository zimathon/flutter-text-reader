import pytest
from unittest.mock import Mock, patch, MagicMock
from google.api_core import exceptions as google_exceptions
from tts_engine import TTSEngine


class TestTTSEngine:
    """Test TTS engine functionality"""
    
    @pytest.fixture
    def mock_tts_client(self):
        """Create mock Google Cloud TTS client"""
        mock = Mock()
        mock.synthesize_speech.return_value = Mock(
            audio_content=b"fake_audio_content"
        )
        mock.list_voices.return_value = Mock(
            voices=[
                Mock(
                    name="ja-JP-Standard-A",
                    language_codes=["ja-JP"],
                    ssml_gender=1,
                    natural_sample_rate_hertz=24000
                ),
                Mock(
                    name="ja-JP-Standard-B",
                    language_codes=["ja-JP"],
                    ssml_gender=1,
                    natural_sample_rate_hertz=24000
                ),
                Mock(
                    name="en-US-Standard-C",
                    language_codes=["en-US"],
                    ssml_gender=1,
                    natural_sample_rate_hertz=24000
                )
            ]
        )
        return mock
    
    @pytest.fixture
    def tts_engine(self, mock_tts_client):
        """Create TTS engine with mock client"""
        with patch("tts_engine.texttospeech.TextToSpeechClient", return_value=mock_tts_client):
            engine = TTSEngine()
            engine.client = mock_tts_client
            return engine
    
    def test_initialize_client_success(self, mock_tts_client):
        """Test successful client initialization"""
        with patch("tts_engine.texttospeech.TextToSpeechClient", return_value=mock_tts_client):
            engine = TTSEngine()
            assert engine.client is not None
    
    def test_initialize_client_failure(self):
        """Test client initialization failure"""
        with patch("tts_engine.texttospeech.TextToSpeechClient", side_effect=Exception("Init failed")):
            engine = TTSEngine()
            assert engine.client is None
    
    def test_synthesize_success(self, tts_engine, mock_tts_client):
        """Test successful speech synthesis"""
        text = "こんにちは、世界"
        voice = "ja-JP-Standard-A"
        
        result = tts_engine.synthesize(
            text=text,
            voice=voice,
            speed=1.0,
            pitch=0.0,
            language="ja-JP",
            volume_gain_db=0.0
        )
        
        assert result == b"fake_audio_content"
        mock_tts_client.synthesize_speech.assert_called_once()
    
    def test_synthesize_with_different_voices(self, tts_engine, mock_tts_client):
        """Test synthesis with different voice types"""
        voices = [
            ("ja-JP-Standard-A", 1),  # Female
            ("ja-JP-Standard-B", 1),  # Female
            ("ja-JP-Standard-C", 2),  # Male
            ("ja-JP-Standard-D", 2),  # Male
        ]
        
        for voice, expected_gender in voices:
            tts_engine.synthesize(
                text="Test",
                voice=voice,
                speed=1.0,
                pitch=0.0,
                language="ja-JP"
            )
    
    def test_synthesize_with_parameters(self, tts_engine, mock_tts_client):
        """Test synthesis with various parameters"""
        result = tts_engine.synthesize(
            text="Test text",
            voice="ja-JP-Standard-A",
            speed=2.0,
            pitch=5.0,
            language="ja-JP",
            volume_gain_db=3.0
        )
        
        assert result == b"fake_audio_content"
        
        # Verify the audio config was created with correct parameters
        call_args = mock_tts_client.synthesize_speech.call_args
        assert call_args is not None
    
    def test_synthesize_no_client(self, tts_engine):
        """Test synthesis when client is not initialized"""
        tts_engine.client = None
        
        result = tts_engine.synthesize(
            text="Test",
            voice="ja-JP-Standard-A"
        )
        
        assert result is None
    
    def test_synthesize_api_error(self, tts_engine, mock_tts_client):
        """Test synthesis with Google API error"""
        mock_tts_client.synthesize_speech.side_effect = google_exceptions.GoogleAPICallError("API Error")
        
        result = tts_engine.synthesize(
            text="Test",
            voice="ja-JP-Standard-A"
        )
        
        assert result is None
    
    def test_synthesize_unexpected_error(self, tts_engine, mock_tts_client):
        """Test synthesis with unexpected error"""
        mock_tts_client.synthesize_speech.side_effect = Exception("Unexpected error")
        
        result = tts_engine.synthesize(
            text="Test",
            voice="ja-JP-Standard-A"
        )
        
        assert result is None
    
    def test_list_voices_success(self, tts_engine, mock_tts_client):
        """Test successful voice listing"""
        voices = tts_engine.list_voices()
        
        assert len(voices) == 3
        assert all("id" in v for v in voices)
        assert all("name" in v for v in voices)
        assert all("language_code" in v for v in voices)
        assert all("ssml_gender" in v for v in voices)
        assert all("natural_sample_rate_hertz" in v for v in voices)
    
    def test_list_voices_with_language_filter(self, tts_engine, mock_tts_client):
        """Test voice listing with language filter"""
        voices = tts_engine.list_voices(language_code="ja-JP")
        
        mock_tts_client.list_voices.assert_called_with(language_code="ja-JP")
    
    def test_list_voices_no_client(self, tts_engine):
        """Test voice listing when client is not initialized"""
        tts_engine.client = None
        
        voices = tts_engine.list_voices()
        
        assert voices == []
    
    def test_list_voices_error(self, tts_engine, mock_tts_client):
        """Test voice listing with error"""
        mock_tts_client.list_voices.side_effect = Exception("List voices error")
        
        voices = tts_engine.list_voices()
        
        assert voices == []
    
    def test_is_available(self, tts_engine):
        """Test engine availability check"""
        assert tts_engine.is_available() is True
        
        tts_engine.client = None
        assert tts_engine.is_available() is False
    
    def test_validate_text_length(self, tts_engine):
        """Test text length validation"""
        assert tts_engine.validate_text_length("Short text", 100) is True
        assert tts_engine.validate_text_length("Short text", 5) is False
        assert tts_engine.validate_text_length("", 100) is True
        assert tts_engine.validate_text_length("a" * 101, 100) is False


class TestTTSEngineIntegration:
    """Integration tests for TTS engine"""
    
    @pytest.mark.skipif(
        not pytest.config.getoption("--integration", default=False),
        reason="Integration tests require --integration flag"
    )
    def test_real_synthesis(self):
        """Test with real Google Cloud TTS (requires credentials)"""
        engine = TTSEngine()
        if not engine.is_available():
            pytest.skip("Google Cloud TTS not available")
        
        result = engine.synthesize(
            text="Integration test",
            voice="en-US-Standard-C",
            language="en-US"
        )
        
        assert result is not None
        assert len(result) > 0