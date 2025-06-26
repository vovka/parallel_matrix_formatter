"""
Cache manager implementation using centralized configuration.

This module provides caching functionality that uses the centralized configuration
system instead of directly accessing environment variables.
"""

import time
import logging
from typing import Any, Optional, Dict
from abc import ABC, abstractmethod
from .config_loader import Config, get_config


class CacheBackend(ABC):
    """Abstract base class for cache backends."""
    
    @abstractmethod
    def get(self, key: str) -> Optional[Any]:
        """Get value from cache."""
        pass
    
    @abstractmethod
    def set(self, key: str, value: Any, ttl: int) -> None:
        """Set value in cache with TTL."""
        pass
    
    @abstractmethod
    def delete(self, key: str) -> bool:
        """Delete value from cache."""
        pass
    
    @abstractmethod
    def clear(self) -> None:
        """Clear all cache entries."""
        pass


class MemoryCacheBackend(CacheBackend):
    """
    In-memory cache backend implementation.
    
    This backend stores cache entries in memory with TTL support.
    """
    
    def __init__(self):
        """Initialize the memory cache backend."""
        self._cache: Dict[str, Dict[str, Any]] = {}
        self._logger = logging.getLogger(__name__ + ".MemoryCacheBackend")
    
    def get(self, key: str) -> Optional[Any]:
        """
        Get value from memory cache.
        
        Args:
            key: Cache key
            
        Returns:
            Cached value or None if not found or expired
        """
        if key not in self._cache:
            return None
        
        entry = self._cache[key]
        current_time = time.time()
        
        # Check if entry has expired
        if current_time > entry['expires_at']:
            del self._cache[key]
            self._logger.debug(f"Cache entry expired: {key}")
            return None
        
        self._logger.debug(f"Cache hit: {key}")
        return entry['value']
    
    def set(self, key: str, value: Any, ttl: int) -> None:
        """
        Set value in memory cache with TTL.
        
        Args:
            key: Cache key
            value: Value to cache
            ttl: Time to live in seconds
        """
        expires_at = time.time() + ttl
        self._cache[key] = {
            'value': value,
            'expires_at': expires_at
        }
        self._logger.debug(f"Cache set: {key} (TTL: {ttl}s)")
    
    def delete(self, key: str) -> bool:
        """
        Delete value from memory cache.
        
        Args:
            key: Cache key
            
        Returns:
            True if key was deleted, False if not found
        """
        if key in self._cache:
            del self._cache[key]
            self._logger.debug(f"Cache deleted: {key}")
            return True
        return False
    
    def clear(self) -> None:
        """Clear all cache entries."""
        self._cache.clear()
        self._logger.debug("Cache cleared")


class CacheManager:
    """
    Cache manager that uses centralized configuration.
    
    This class demonstrates how to use configuration settings instead of
    directly accessing environment variables for cache configuration.
    """
    
    def __init__(self, config: Config):
        """
        Initialize the cache manager with configuration.
        
        Args:
            config: Centralized configuration object
        """
        self._config = config
        self._logger = self._setup_logging()
        self._backend = self._create_backend()
    
    def _setup_logging(self) -> logging.Logger:
        """
        Set up logging using configuration settings.
        
        Returns:
            Configured logger instance
        """
        logger = logging.getLogger(__name__ + ".CacheManager")
        level = getattr(logging, self._config.logging.level.upper())
        logger.setLevel(level)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(self._config.logging.format)
            handler.setFormatter(formatter)
            logger.addHandler(handler)
        
        return logger
    
    def _create_backend(self) -> CacheBackend:
        """
        Create cache backend based on configuration.
        
        Returns:
            Configured cache backend instance
            
        Raises:
            ValueError: If backend type is not supported
        """
        backend_type = self._config.cache.backend.lower()
        
        if backend_type == "memory":
            return MemoryCacheBackend()
        else:
            # In a real implementation, you might add Redis or other backends
            raise ValueError(f"Unsupported cache backend: {backend_type}")
    
    def is_enabled(self) -> bool:
        """
        Check if caching is enabled according to configuration.
        
        Returns:
            True if caching is enabled, False otherwise
        """
        return self._config.cache.enabled
    
    def get(self, key: str) -> Optional[Any]:
        """
        Get value from cache if caching is enabled.
        
        Args:
            key: Cache key
            
        Returns:
            Cached value or None if not found, expired, or caching disabled
        """
        if not self.is_enabled():
            self._logger.debug("Caching disabled, cache get ignored")
            return None
        
        return self._backend.get(key)
    
    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        """
        Set value in cache if caching is enabled.
        
        Args:
            key: Cache key
            value: Value to cache
            ttl: Time to live in seconds (uses config default if None)
        """
        if not self.is_enabled():
            self._logger.debug("Caching disabled, cache set ignored")
            return
        
        # Use configured TTL if not specified
        cache_ttl = ttl if ttl is not None else self._config.cache.ttl
        
        self._backend.set(key, value, cache_ttl)
    
    def delete(self, key: str) -> bool:
        """
        Delete value from cache if caching is enabled.
        
        Args:
            key: Cache key
            
        Returns:
            True if key was deleted, False if not found or caching disabled
        """
        if not self.is_enabled():
            self._logger.debug("Caching disabled, cache delete ignored")
            return False
        
        return self._backend.delete(key)
    
    def clear(self) -> None:
        """Clear all cache entries if caching is enabled."""
        if not self.is_enabled():
            self._logger.debug("Caching disabled, cache clear ignored")
            return
        
        self._backend.clear()
        self._logger.info("Cache cleared")


def create_cache_manager() -> CacheManager:
    """
    Factory function to create a CacheManager with centralized configuration.
    
    This demonstrates the recommended pattern where configuration is loaded
    centrally and passed to components rather than each component loading
    configuration independently.
    
    Returns:
        Configured CacheManager instance
    """
    # Use centralized configuration
    config = get_config()
    
    # Create cache manager with the config
    return CacheManager(config)