"""
VibeVoice API Server
Text-to-Speech API server using Google Cloud Text-to-Speech
"""

import os
import hashlib
import json
from typing import Optional, List
from datetime import datetime, timedelta
import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
import redis.asyncio as redis
from google.cloud import texttospeech
from dotenv import load_dotenv
import uvicorn

# Load environment variables
load_dotenv()

# Configuration
PORT = int(os.getenv("PORT", 5000))
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
RATE_LIMIT_PER_MINUTE = int(os.getenv("RATE_LIMIT_PER_MINUTE", 60))
CACHE_TTL_HOURS = int(os.getenv("CACHE_TTL_HOURS", 24))
MAX_TEXT_LENGTH = int(os.getenv("MAX_TEXT_LENGTH", 5000))
ENABLE_CORS = os.getenv("ENABLE_CORS", "true").lower() == "true"
CORS_ORIGINS = json.loads(os.getenv("CORS_ORIGINS", '["*"]'))

# Global clients
redis_client: Optional[redis.Redis] = None
tts_client: Optional[texttospeech.TextToSpeechClient] = None


# Request/Response models
class SynthesizeRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=MAX_TEXT_LENGTH)
    voice: str = Field(default="ja-JP-Standard-A")
    speed: float = Field(default=1.0, ge=0.25, le=4.0)
    pitch: float = Field(default=0.0, ge=-20.0, le=20.0)
    language: str = Field(default="ja-JP")


class VoiceInfo(BaseModel):
    name: str
    language_codes: List[str]
    ssml_gender: str
    natural_sample_rate_hertz: int


class ServerInfo(BaseModel):
    version: str
    supported_languages: List[str]
    max_text_length: int
    cache_enabled: bool
    rate_limit_per_minute: int


# Utility functions
def generate_cache_key(request: SynthesizeRequest) -> str:
    """Generate a unique cache key for the synthesis request"""
    key_data = f"{request.text}:{request.voice}:{request.speed}:{request.pitch}:{request.language}"
    return hashlib.sha256(key_data.encode()).hexdigest()


async def check_rate_limit(client_ip: str) -> bool:
    """Check if the client has exceeded the rate limit"""
    if not redis_client:
        return True
    
    key = f"rate_limit:{client_ip}"
    try:
        count = await redis_client.incr(key)
        if count == 1:
            await redis_client.expire(key, 60)  # 1 minute window
        return count <= RATE_LIMIT_PER_MINUTE
    except Exception:
        return True  # Allow on Redis error


async def get_cached_audio(cache_key: str) -> Optional[bytes]:
    """Retrieve cached audio data"""
    if not redis_client:
        return None
    
    try:
        data = await redis_client.get(f"audio:{cache_key}")
        return data
    except Exception:
        return None


async def cache_audio(cache_key: str, audio_data: bytes):
    """Cache audio data with TTL"""
    if not redis_client:
        return
    
    try:
        await redis_client.setex(
            f"audio:{cache_key}",
            CACHE_TTL_HOURS * 3600,
            audio_data
        )
    except Exception:
        pass  # Fail silently on cache errors


def synthesize_speech(request: SynthesizeRequest) -> bytes:
    """Synthesize speech using Google Cloud Text-to-Speech"""
    if not tts_client:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="TTS service not available"
        )
    
    # Set the text input
    synthesis_input = texttospeech.SynthesisInput(text=request.text)
    
    # Build the voice request
    voice = texttospeech.VoiceSelectionParams(
        language_code=request.language,
        name=request.voice,
    )
    
    # Select the audio format
    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3,
        speaking_rate=request.speed,
        pitch=request.pitch,
    )
    
    # Perform the text-to-speech request
    response = tts_client.synthesize_speech(
        input=synthesis_input,
        voice=voice,
        audio_config=audio_config
    )
    
    return response.audio_content


# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize and cleanup resources"""
    global redis_client, tts_client
    
    # Initialize Redis client
    try:
        redis_client = redis.from_url(REDIS_URL)
        await redis_client.ping()
        print("Redis connected successfully")
    except Exception as e:
        print(f"Redis connection failed: {e}")
        redis_client = None
    
    # Initialize Google Cloud TTS client
    try:
        tts_client = texttospeech.TextToSpeechClient()
        print("Google Cloud TTS client initialized")
    except Exception as e:
        print(f"Google Cloud TTS initialization failed: {e}")
        tts_client = None
    
    yield
    
    # Cleanup
    if redis_client:
        await redis_client.close()


# Create FastAPI app
app = FastAPI(
    title="VibeVoice API",
    description="Text-to-Speech API Server",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
if ENABLE_CORS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


# API Endpoints
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "timestamp": datetime.now().isoformat(),
        "redis": redis_client is not None,
        "tts": tts_client is not None
    }


@app.get("/info", response_model=ServerInfo)
async def server_info():
    """Get server information"""
    return ServerInfo(
        version="1.0.0",
        supported_languages=["ja-JP", "en-US", "zh-CN", "ko-KR"],
        max_text_length=MAX_TEXT_LENGTH,
        cache_enabled=redis_client is not None,
        rate_limit_per_minute=RATE_LIMIT_PER_MINUTE
    )


@app.get("/voices", response_model=List[VoiceInfo])
async def list_voices(language_code: Optional[str] = "ja-JP"):
    """List available voices"""
    if not tts_client:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="TTS service not available"
        )
    
    # Get the list of available voices
    voices = tts_client.list_voices(language_code=language_code)
    
    voice_list = []
    for voice in voices.voices:
        voice_list.append(VoiceInfo(
            name=voice.name,
            language_codes=voice.language_codes,
            ssml_gender=texttospeech.SsmlVoiceGender(voice.ssml_gender).name,
            natural_sample_rate_hertz=voice.natural_sample_rate_hertz
        ))
    
    return voice_list


@app.post("/synthesize")
async def synthesize(request: SynthesizeRequest, req: Request):
    """Synthesize text to speech"""
    # Rate limiting
    client_ip = req.client.host
    if not await check_rate_limit(client_ip):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded",
            headers={"Retry-After": "60"}
        )
    
    # Generate cache key
    cache_key = generate_cache_key(request)
    
    # Check cache
    cached_audio = await get_cached_audio(cache_key)
    if cached_audio:
        return Response(
            content=cached_audio,
            media_type="audio/mpeg",
            headers={
                "X-Cache": "HIT",
                "Cache-Control": f"max-age={CACHE_TTL_HOURS * 3600}"
            }
        )
    
    # Synthesize speech
    try:
        audio_content = await asyncio.to_thread(synthesize_speech, request)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Speech synthesis failed: {str(e)}"
        )
    
    # Cache the result
    await cache_audio(cache_key, audio_content)
    
    return Response(
        content=audio_content,
        media_type="audio/mpeg",
        headers={
            "X-Cache": "MISS",
            "Cache-Control": f"max-age={CACHE_TTL_HOURS * 3600}"
        }
    )


@app.get("/cache/stats")
async def cache_stats():
    """Get cache statistics"""
    if not redis_client:
        return {"cache_enabled": False}
    
    try:
        info = await redis_client.info("stats")
        keys = await redis_client.dbsize()
        
        return {
            "cache_enabled": True,
            "total_keys": keys,
            "keyspace_hits": info.get("keyspace_hits", 0),
            "keyspace_misses": info.get("keyspace_misses", 0),
            "hit_rate": info.get("keyspace_hits", 0) / 
                       (info.get("keyspace_hits", 0) + info.get("keyspace_misses", 1))
        }
    except Exception as e:
        return {"cache_enabled": False, "error": str(e)}


@app.delete("/cache/clear")
async def clear_cache():
    """Clear all cached audio (admin endpoint)"""
    if not redis_client:
        return {"message": "Cache not enabled"}
    
    try:
        # Clear only audio keys
        keys = await redis_client.keys("audio:*")
        if keys:
            await redis_client.delete(*keys)
        return {"message": f"Cleared {len(keys)} cached items"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Cache clear failed: {str(e)}"
        )


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=PORT,
        reload=True
    )