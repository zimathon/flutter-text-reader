import os
import logging
from typing import Optional, List, Dict, Any
from google.cloud import texttospeech
from google.api_core import exceptions as google_exceptions

logger = logging.getLogger(__name__)


class TTSEngine:
    def __init__(self):
        self.client = None
        self.initialize_client()
    
    def initialize_client(self):
        """Initialize Google Cloud TTS client"""
        try:
            self.client = texttospeech.TextToSpeechClient()
            logger.info("Google Cloud TTS client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Google Cloud TTS client: {e}")
            self.client = None
    
    def synthesize(
        self,
        text: str,
        voice: str,
        speed: float = 1.0,
        pitch: float = 0.0,
        language: str = "ja-JP",
        volume_gain_db: float = 0.0
    ) -> Optional[bytes]:
        """Synthesize text to speech using Google Cloud TTS"""
        
        if not self.client:
            logger.error("TTS client not initialized")
            return None
        
        try:
            # Set the text input to be synthesized
            synthesis_input = texttospeech.SynthesisInput(text=text)
            
            # Extract gender from voice name (assumes format like ja-JP-Standard-A)
            # A, B are typically female, C, D are typically male
            voice_parts = voice.split("-")
            if len(voice_parts) >= 4:
                voice_variant = voice_parts[-1]
                if voice_variant in ["A", "B"]:
                    ssml_gender = texttospeech.SsmlVoiceGender.FEMALE
                else:
                    ssml_gender = texttospeech.SsmlVoiceGender.MALE
            else:
                ssml_gender = texttospeech.SsmlVoiceGender.NEUTRAL
            
            # Build the voice request
            voice_params = texttospeech.VoiceSelectionParams(
                language_code=language,
                name=voice,
                ssml_gender=ssml_gender
            )
            
            # Select the type of audio file you want returned
            audio_config = texttospeech.AudioConfig(
                audio_encoding=texttospeech.AudioEncoding.LINEAR16,  # WAV format
                speaking_rate=speed,
                pitch=pitch,
                volume_gain_db=volume_gain_db
            )
            
            # Perform the text-to-speech request
            response = self.client.synthesize_speech(
                input=synthesis_input,
                voice=voice_params,
                audio_config=audio_config
            )
            
            logger.info(f"Successfully synthesized {len(text)} characters")
            return response.audio_content
            
        except google_exceptions.GoogleAPICallError as e:
            logger.error(f"Google API error during synthesis: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error during synthesis: {e}")
            return None
    
    def list_voices(self, language_code: Optional[str] = None) -> List[Dict[str, Any]]:
        """List available voices from Google Cloud TTS"""
        
        if not self.client:
            logger.error("TTS client not initialized")
            return []
        
        try:
            # Performs the list voices request
            voices = self.client.list_voices(language_code=language_code)
            
            voice_list = []
            for voice in voices.voices:
                # Get the primary language code
                primary_language = voice.language_codes[0] if voice.language_codes else ""
                
                voice_info = {
                    "id": voice.name,
                    "name": voice.name,
                    "language_code": primary_language,
                    "ssml_gender": texttospeech.SsmlVoiceGender(voice.ssml_gender).name,
                    "natural_sample_rate_hertz": voice.natural_sample_rate_hertz
                }
                voice_list.append(voice_info)
            
            # Filter for Japanese and English voices if no specific language requested
            if not language_code:
                voice_list = [
                    v for v in voice_list 
                    if v["language_code"] in ["ja-JP", "en-US"]
                ]
            
            logger.info(f"Retrieved {len(voice_list)} voices")
            return voice_list
            
        except Exception as e:
            logger.error(f"Error listing voices: {e}")
            return []
    
    def is_available(self) -> bool:
        """Check if TTS engine is available"""
        return self.client is not None
    
    def validate_text_length(self, text: str, max_length: int) -> bool:
        """Validate text length"""
        return len(text) <= max_length