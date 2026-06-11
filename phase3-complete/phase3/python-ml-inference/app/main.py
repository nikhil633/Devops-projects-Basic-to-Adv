# app/main.py
#
# ML Inference API — FastAPI + ONNX Runtime
#
# Architecture:
#   HTTP layer (FastAPI)
#     POST /predict          — single prediction
#     POST /predict/batch    — batch predictions
#     GET  /models           — list loaded models
#     GET  /health, /metrics
#
#   Async batching engine
#     Requests go into an asyncio.Queue.
#     A background worker drains the queue every BATCH_WINDOW_MS milliseconds
#     or when BATCH_MAX_SIZE requests have queued — whichever comes first.
#     The batch is passed to ONNX Runtime in one inference call.
#     Each caller's asyncio.Future is resolved with its slice of results.
#
# Why async batching?
#   ONNX Runtime (and GPU kernels generally) are more efficient with larger
#   batches — the per-sample overhead amortises across the batch.
#   A single inference call for 32 samples is far cheaper than 32 calls
#   for 1 sample each. The batching engine groups concurrent HTTP requests
#   automatically without the client knowing.

from contextlib import asynccontextmanager
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

from app.api.routes import router
from app.core.model_registry import ModelRegistry
from app.core.batch_engine import BatchEngine
from app.core.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ──────────────────────────────────────────────────────────
    registry = ModelRegistry()
    await registry.load_all()

    engine = BatchEngine(registry)
    await engine.start()

    # Attach to app state so routes can access them
    app.state.registry = registry
    app.state.engine   = engine

    yield

    # ── Shutdown ─────────────────────────────────────────────────────────
    await engine.stop()


app = FastAPI(
    title="ML Inference API",
    description="ONNX model serving with async request batching",
    version="1.0.0",
    lifespan=lifespan,
)

Instrumentator().instrument(app).expose(app)
app.include_router(router)
