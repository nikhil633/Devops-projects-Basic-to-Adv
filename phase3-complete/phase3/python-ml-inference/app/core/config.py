# app/core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Batching engine tunables
    batch_max_size:    int   = 32     # max requests per batch
    batch_window_ms:   float = 10.0   # max wait before flushing a partial batch
    max_queue_depth:   int   = 1000   # backpressure: reject requests beyond this

    # Model storage
    models_dir:        str   = "app/models"

    # Redis (for request logging / distributed rate limiting)
    redis_url:         str   = "redis://localhost:6379"

    log_level:         str   = "info"

    class Config:
        env_file = ".env"

settings = Settings()
