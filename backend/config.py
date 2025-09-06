from pydantic_settings import BaseSettings
from typing import List
import os


class Settings(BaseSettings):
    port: int = 5000
    google_application_credentials: str = ""
    redis_url: str = "redis://localhost:6379"
    rate_limit_per_minute: int = 60
    cache_ttl_hours: int = 24
    max_text_length: int = 5000
    cors_origins: List[str] = ["http://localhost:3000", "http://localhost:8080"]
    debug: bool = False
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Set Google credentials environment variable if provided
        if self.google_application_credentials:
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = self.google_application_credentials


settings = Settings()