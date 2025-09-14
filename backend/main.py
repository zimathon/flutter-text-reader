import logging
import sys
from datetime import datetime
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException, Response, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from config import settings
from models import (
    SynthesizeRequest, HealthResponse, InfoResponse,
    ErrorResponse, VoicesResponse, VoiceInfo, CacheStats
)
from cache_manager import CacheManager
from tts_engine import TTSEngine

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Initialize components
cache_manager: Optional[CacheManager] = None
tts_engine: Optional[TTSEngine] = None

# Initialize rate limiter
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[f"{settings.rate_limit_per_minute}/minute"]
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    global cache_manager, tts_engine
    
    logger.info("Starting VibeVoice API server...")
    
    # Initialize cache manager
    try:
        cache_manager = CacheManager(
            redis_url=settings.redis_url,
            ttl_hours=settings.cache_ttl_hours
        )
        logger.info("Cache manager initialized")
    except Exception as e:
        logger.error(f"Failed to initialize cache manager: {e}")
        cache_manager = None
    
    # Initialize TTS engine
    try:
        tts_engine = TTSEngine()
        logger.info("TTS engine initialized")
    except Exception as e:
        logger.error(f"Failed to initialize TTS engine: {e}")
        tts_engine = None
    
    yield
    
    # Shutdown
    logger.info("Shutting down VibeVoice API server...")

# Create FastAPI app
app = FastAPI(
    title="VibeVoice API",
    description="Text-to-Speech API Server",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    redis_connected = cache_manager.is_connected() if cache_manager else False
    tts_available = tts_engine.is_available() if tts_engine else False
    
    return HealthResponse(
        status="ok" if (redis_connected or tts_available) else "degraded",
        timestamp=datetime.utcnow().isoformat(),
        redis_connected=redis_connected,
        google_tts_available=tts_available
    )

@app.get("/info", response_model=InfoResponse)
async def server_info():
    """Get server information"""
    available_voices = []
    
    if tts_engine:
        voices = tts_engine.list_voices()
        available_voices = [v["id"] for v in voices]
    
    return InfoResponse(
        version="1.0.0",
        supported_languages=["ja-JP", "en-US"],
        max_text_length=settings.max_text_length,
        available_voices=available_voices,
        rate_limit=settings.rate_limit_per_minute,
        cache_ttl_hours=settings.cache_ttl_hours
    )

@app.get("/voices", response_model=VoicesResponse)
async def list_voices(language_code: Optional[str] = None):
    """List available voices"""
    if not tts_engine:
        raise HTTPException(status_code=503, detail="TTS engine not available")
    
    voices = tts_engine.list_voices(language_code)
    
    voice_infos = [
        VoiceInfo(
            id=v["id"],
            name=v["name"],
            language_code=v["language_code"],
            ssml_gender=v["ssml_gender"],
            natural_sample_rate_hertz=v["natural_sample_rate_hertz"]
        )
        for v in voices
    ]
    
    return VoicesResponse(voices=voice_infos)

@app.post("/synthesize")
@limiter.limit(f"{settings.rate_limit_per_minute}/minute")
async def synthesize_speech(
    request: Request,
    synthesize_request: SynthesizeRequest
):
    """Synthesize text to speech"""
    
    # Validate text length
    if len(synthesize_request.text) > settings.max_text_length:
        raise HTTPException(
            status_code=400,
            detail=f"Text exceeds maximum length of {settings.max_text_length} characters"
        )
    
    # Check if TTS engine is available
    if not tts_engine:
        raise HTTPException(status_code=503, detail="TTS engine not available")
    
    # Generate cache key
    cache_key = None
    if cache_manager:
        cache_key = cache_manager._generate_key(
            text=synthesize_request.text,
            voice=synthesize_request.voice.value,
            speed=synthesize_request.speed,
            pitch=synthesize_request.pitch,
            language=synthesize_request.language.value,
            volume_gain_db=synthesize_request.volume_gain_db
        )
        
        # Try to get from cache
        cached_audio = cache_manager.get(cache_key)
        if cached_audio:
            logger.info("Returning cached audio")
            return Response(
                content=cached_audio,
                media_type="audio/wav",
                headers={
                    "X-Cache": "HIT",
                    "Cache-Control": f"max-age={settings.cache_ttl_hours * 3600}"
                }
            )
    
    # Synthesize audio
    audio_content = tts_engine.synthesize(
        text=synthesize_request.text,
        voice=synthesize_request.voice.value,
        speed=synthesize_request.speed,
        pitch=synthesize_request.pitch,
        language=synthesize_request.language.value,
        volume_gain_db=synthesize_request.volume_gain_db
    )
    
    if not audio_content:
        raise HTTPException(status_code=500, detail="Failed to synthesize audio")
    
    # Store in cache
    if cache_manager and cache_key:
        cache_manager.set(cache_key, audio_content)
    
    return Response(
        content=audio_content,
        media_type="audio/wav",
        headers={
            "X-Cache": "MISS",
            "Cache-Control": f"max-age={settings.cache_ttl_hours * 3600}"
        }
    )

@app.get("/cache/stats", response_model=CacheStats)
async def get_cache_stats():
    """Get cache statistics"""
    if not cache_manager:
        raise HTTPException(status_code=503, detail="Cache not available")
    
    stats = cache_manager.get_stats()
    return CacheStats(**stats)

@app.delete("/cache")
async def clear_cache():
    """Clear all cache entries"""
    if not cache_manager:
        raise HTTPException(status_code=503, detail="Cache not available")
    
    cleared = cache_manager.clear_all()
    return {"message": f"Cleared {cleared} cache entries"}

# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            error=exc.detail,
            code=exc.status_code
        ).model_dump()
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="Internal server error",
            detail=str(exc) if settings.debug else None,
            code=500
        ).model_dump()
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=settings.port,
        reload=True,
        log_level="info"
    )