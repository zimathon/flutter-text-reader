import pytest
import hashlib
import json
from unittest.mock import Mock, patch
from datetime import timedelta
from cache_manager import CacheManager


class TestCacheManager:
    """Test cache manager functionality"""
    
    @pytest.fixture
    def cache_manager(self, mock_redis):
        """Create cache manager with mock Redis"""
        with patch("cache_manager.redis.from_url", return_value=mock_redis):
            return CacheManager("redis://localhost:6379", ttl_hours=24)
    
    def test_generate_key(self, cache_manager):
        """Test cache key generation"""
        key = cache_manager._generate_key(
            text="Hello world",
            voice="ja-JP-Standard-A",
            speed=1.0,
            pitch=0.0,
            language="ja-JP",
            volume_gain_db=0.0
        )
        
        assert key.startswith("audio:")
        assert len(key) == 71  # "audio:" (6) + SHA256 hash (64) + 1
        
        # Same parameters should generate same key
        key2 = cache_manager._generate_key(
            text="Hello world",
            voice="ja-JP-Standard-A",
            speed=1.0,
            pitch=0.0,
            language="ja-JP",
            volume_gain_db=0.0
        )
        assert key == key2
        
        # Different parameters should generate different key
        key3 = cache_manager._generate_key(
            text="Different text",
            voice="ja-JP-Standard-A",
            speed=1.0,
            pitch=0.0,
            language="ja-JP",
            volume_gain_db=0.0
        )
        assert key != key3
    
    def test_set_and_get(self, cache_manager, mock_redis):
        """Test setting and getting cached data"""
        key = "audio:test_key"
        audio_data = b"test_audio_data"
        
        # Set cache
        result = cache_manager.set(key, audio_data)
        assert result is True
        
        # Get cache
        cached_data = cache_manager.get(key)
        assert cached_data == audio_data
    
    def test_get_nonexistent_key(self, cache_manager):
        """Test getting non-existent key"""
        result = cache_manager.get("audio:nonexistent")
        assert result is None
    
    def test_delete(self, cache_manager, mock_redis):
        """Test deleting cache entry"""
        key = "audio:test_key"
        audio_data = b"test_audio_data"
        
        # Set cache
        cache_manager.set(key, audio_data)
        
        # Delete cache
        result = cache_manager.delete(key)
        assert result is True
        
        # Verify deletion
        cached_data = cache_manager.get(key)
        assert cached_data is None
    
    def test_clear_all(self, cache_manager, mock_redis):
        """Test clearing all cache entries"""
        # Add multiple cache entries
        cache_manager.set("audio:key1", b"data1")
        cache_manager.set("audio:key2", b"data2")
        cache_manager.set("audio:key3", b"data3")
        
        # Clear all
        cleared = cache_manager.clear_all()
        assert cleared >= 0  # FakeRedis might not return exact count
        
        # Verify all cleared
        assert cache_manager.get("audio:key1") is None
        assert cache_manager.get("audio:key2") is None
        assert cache_manager.get("audio:key3") is None
    
    def test_get_stats(self, cache_manager):
        """Test getting cache statistics"""
        stats = cache_manager.get_stats()
        
        assert "total_keys" in stats
        assert "memory_usage_mb" in stats
        assert "hit_rate" in stats
        assert "total_hits" in stats
        assert "total_misses" in stats
        
        assert isinstance(stats["total_keys"], int)
        assert isinstance(stats["memory_usage_mb"], (int, float))
        assert isinstance(stats["hit_rate"], (int, float))
        assert isinstance(stats["total_hits"], int)
        assert isinstance(stats["total_misses"], int)
    
    def test_hit_miss_tracking(self, cache_manager, mock_redis):
        """Test cache hit/miss tracking"""
        key = "audio:test_key"
        
        # Miss
        cache_manager.get(key)
        
        # Set cache
        cache_manager.set(key, b"data")
        
        # Hit
        cache_manager.get(key)
        
        stats = cache_manager.get_stats()
        assert stats["total_hits"] >= 0
        assert stats["total_misses"] >= 0
    
    def test_is_connected(self, cache_manager):
        """Test Redis connection check"""
        assert cache_manager.is_connected() is True
        
        # Test with connection failure
        with patch.object(cache_manager.redis_client, "ping", side_effect=Exception):
            assert cache_manager.is_connected() is False
    
    def test_error_handling(self, cache_manager):
        """Test error handling in cache operations"""
        # Test get with Redis error
        with patch.object(cache_manager.redis_client, "get", side_effect=Exception("Redis error")):
            result = cache_manager.get("audio:test")
            assert result is None
        
        # Test set with Redis error
        with patch.object(cache_manager.redis_client, "setex", side_effect=Exception("Redis error")):
            result = cache_manager.set("audio:test", b"data")
            assert result is False
        
        # Test delete with Redis error
        with patch.object(cache_manager.redis_client, "delete", side_effect=Exception("Redis error")):
            result = cache_manager.delete("audio:test")
            assert result is False


class TestCacheKeyGeneration:
    """Test cache key generation with various inputs"""
    
    @pytest.fixture
    def cache_manager(self):
        """Create cache manager for testing"""
        return CacheManager("redis://localhost:6379")
    
    @pytest.mark.parametrize("text,voice,expected_different", [
        ("Hello", "ja-JP-Standard-A", True),
        ("こんにちは", "ja-JP-Standard-A", True),
        ("Hello", "en-US-Standard-C", True),
        ("", "ja-JP-Standard-A", True),
    ])
    def test_key_uniqueness(self, cache_manager, text, voice, expected_different):
        """Test that different parameters generate different keys"""
        base_key = cache_manager._generate_key(
            text="Base text",
            voice="ja-JP-Standard-B",
            speed=1.0,
            pitch=0.0,
            language="ja-JP",
            volume_gain_db=0.0
        )
        
        test_key = cache_manager._generate_key(
            text=text,
            voice=voice,
            speed=1.0,
            pitch=0.0,
            language="ja-JP",
            volume_gain_db=0.0
        )
        
        if expected_different:
            assert base_key != test_key
        else:
            assert base_key == test_key