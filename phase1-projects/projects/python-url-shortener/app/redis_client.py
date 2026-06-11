import redis.asyncio as redis
import os

_client = None

async def get_redis():
    global _client
    if _client is None:
        _client = redis.from_url(
            os.getenv("REDIS_URL", "redis://localhost:6379"),
            decode_responses=True
        )
    return _client
