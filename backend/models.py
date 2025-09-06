from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum


class VoiceType(str, Enum):
    JA_JP_STANDARD_A = "ja-JP-Standard-A"  # Female
    JA_JP_STANDARD_B = "ja-JP-Standard-B"  # Female
    JA_JP_STANDARD_C = "ja-JP-Standard-C"  # Male
    JA_JP_STANDARD_D = "ja-JP-Standard-D"  # Male
    JA_JP_WAVENET_A = "ja-JP-Wavenet-A"    # Female (Higher quality)
    JA_JP_WAVENET_B = "ja-JP-Wavenet-B"    # Female (Higher quality)
    JA_JP_WAVENET_C = "ja-JP-Wavenet-C"    # Male (Higher quality)
    JA_JP_WAVENET_D = "ja-JP-Wavenet-D"    # Male (Higher quality)
    EN_US_STANDARD_A = "en-US-Standard-A"  # Male
    EN_US_STANDARD_B = "en-US-Standard-B"  # Male
    EN_US_STANDARD_C = "en-US-Standard-C"  # Female
    EN_US_STANDARD_D = "en-US-Standard-D"  # Male


class LanguageCode(str, Enum):
    JA_JP = "ja-JP"
    EN_US = "en-US"
    

class SynthesizeRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=5000, description="Text to synthesize")
    voice: VoiceType = Field(default=VoiceType.JA_JP_STANDARD_A, description="Voice type to use")
    speed: float = Field(default=1.0, ge=0.25, le=4.0, description="Speech speed (0.25-4.0)")
    pitch: float = Field(default=0.0, ge=-20.0, le=20.0, description="Voice pitch (-20.0 to 20.0)")
    language: LanguageCode = Field(default=LanguageCode.JA_JP, description="Language code")
    volume_gain_db: float = Field(default=0.0, ge=-96.0, le=16.0, description="Volume gain in dB")
    

class HealthResponse(BaseModel):
    status: str
    timestamp: str
    redis_connected: bool
    google_tts_available: bool


class InfoResponse(BaseModel):
    version: str
    supported_languages: List[str]
    max_text_length: int
    available_voices: List[str]
    rate_limit: int
    cache_ttl_hours: int


class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None
    code: int


class VoiceInfo(BaseModel):
    id: str
    name: str
    language_code: str
    ssml_gender: str
    natural_sample_rate_hertz: int


class VoicesResponse(BaseModel):
    voices: List[VoiceInfo]
    

class CacheStats(BaseModel):
    total_keys: int
    memory_usage_mb: float
    hit_rate: float
    total_hits: int
    total_misses: int