import redis
import hashlib
import json
from typing import Optional, Dict, Any
from datetime import timedelta
import logging

logger = logging.getLogger(__name__)


class CacheManager:
    def __init__(self, redis_url: str, ttl_hours: int = 24):
        self.redis_client = redis.from_url(redis_url, decode_responses=False)
        self.ttl = timedelta(hours=ttl_hours)
        self.stats_key = "cache:stats"
        
    def _generate_key(self, text: str, voice: str, speed: float, pitch: float, language: str, volume_gain_db: float) -> str:
        """Generate a unique cache key based on synthesis parameters"""
        params = {
            "text": text,
            "voice": voice,
            "speed": speed,
            "pitch": pitch,
            "language": language,
            "volume_gain_db": volume_gain_db
        }
        
        # Create a stable hash of the parameters
        params_str = json.dumps(params, sort_keys=True)
        hash_obj = hashlib.sha256(params_str.encode())
        return f"audio:{hash_obj.hexdigest()}"
    
    def get(self, key: str) -> Optional[bytes]:
        """Get cached audio data"""
        try:
            data = self.redis_client.get(key)
            if data:
                self._increment_stat("hits")
                logger.info(f"Cache hit for key: {key[:16]}...")
            else:
                self._increment_stat("misses")
                logger.info(f"Cache miss for key: {key[:16]}...")
            return data
        except Exception as e:
            logger.error(f"Cache get error: {e}")
            return None
    
    def set(self, key: str, audio_data: bytes) -> bool:
        """Store audio data in cache"""
        try:
            self.redis_client.setex(key, self.ttl, audio_data)
            logger.info(f"Cached audio for key: {key[:16]}... (size: {len(audio_data)} bytes)")
            return True
        except Exception as e:
            logger.error(f"Cache set error: {e}")
            return False
    
    def delete(self, key: str) -> bool:
        """Delete a cache entry"""
        try:
            result = self.redis_client.delete(key)
            return result > 0
        except Exception as e:
            logger.error(f"Cache delete error: {e}")
            return False
    
    def clear_all(self) -> int:
        """Clear all audio cache entries"""
        try:
            keys = self.redis_client.keys("audio:*")
            if keys:
                return self.redis_client.delete(*keys)
            return 0
        except Exception as e:
            logger.error(f"Cache clear error: {e}")
            return 0
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        try:
            # Get basic stats from Redis INFO
            info = self.redis_client.info("memory")
            keys_count = self.redis_client.dbsize()
            
            # Get custom stats
            hits = int(self.redis_client.hget(self.stats_key, "hits") or 0)
            misses = int(self.redis_client.hget(self.stats_key, "misses") or 0)
            
            total_requests = hits + misses
            hit_rate = (hits / total_requests * 100) if total_requests > 0 else 0
            
            return {
                "total_keys": keys_count,
                "memory_usage_mb": info.get("used_memory", 0) / (1024 * 1024),
                "hit_rate": round(hit_rate, 2),
                "total_hits": hits,
                "total_misses": misses
            }
        except Exception as e:
            logger.error(f"Error getting cache stats: {e}")
            return {
                "total_keys": 0,
                "memory_usage_mb": 0,
                "hit_rate": 0,
                "total_hits": 0,
                "total_misses": 0
            }
    
    def _increment_stat(self, stat_name: str):
        """Increment a statistics counter"""
        try:
            self.redis_client.hincrby(self.stats_key, stat_name, 1)
        except Exception as e:
            logger.error(f"Error incrementing stat {stat_name}: {e}")
    
    def is_connected(self) -> bool:
        """Check if Redis is connected"""
        try:
            self.redis_client.ping()
            return True
        except:
            return False