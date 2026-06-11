from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel, HttpUrl
from app.redis_client import get_redis
import hashlib, time

app = FastAPI(title="URL Shortener")
Instrumentator().instrument(app).expose(app)

class ShortenRequest(BaseModel):
    url: HttpUrl
    ttl: int = 86400  # seconds, default 1 day

class ShortenResponse(BaseModel):
    short_code: str
    short_url: str

@app.get("/health")
def health():
    return {"status": "ok", "timestamp": time.time()}

@app.post("/shorten", response_model=ShortenResponse)
async def shorten(req: ShortenRequest):
    code = hashlib.md5(str(req.url).encode()).hexdigest()[:7]
    r = await get_redis()
    await r.set(code, str(req.url), ex=req.ttl)
    return ShortenResponse(short_code=code, short_url=f"http://localhost:8000/{code}")

@app.get("/{code}")
async def redirect(code: str):
    r = await get_redis()
    url = await r.get(code)
    if not url:
        raise HTTPException(status_code=404, detail="Short code not found or expired")
    return RedirectResponse(url=url)
