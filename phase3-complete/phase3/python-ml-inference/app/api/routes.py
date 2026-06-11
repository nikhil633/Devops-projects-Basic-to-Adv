# app/api/routes.py

import time
import numpy as np
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, field_validator
from typing import Optional

router = APIRouter()


# ── Request / Response schemas ─────────────────────────────────────────────

class PredictRequest(BaseModel):
    inputs:     list[float]
    model_name: Optional[str] = None  # uses default model if omitted

    @field_validator("inputs")
    @classmethod
    def inputs_not_empty(cls, v):
        if not v:
            raise ValueError("inputs must not be empty")
        return v


class PredictResponse(BaseModel):
    model_name:    str
    predictions:   list[float]
    latency_ms:    float


class BatchPredictRequest(BaseModel):
    inputs:     list[list[float]]   # list of samples
    model_name: Optional[str] = None

    @field_validator("inputs")
    @classmethod
    def inputs_not_empty(cls, v):
        if not v:
            raise ValueError("inputs must not be empty")
        return v


class BatchPredictResponse(BaseModel):
    model_name:  str
    predictions: list[list[float]]
    batch_size:  int
    latency_ms:  float


# ── Routes ─────────────────────────────────────────────────────────────────

@router.get("/health")
async def health(request: Request):
    registry = request.app.state.registry
    return {
        "status": "ok",
        "models_loaded": len(registry.list_models()),
        "timestamp": int(time.time()),
    }

@router.get("/models")
async def list_models(request: Request):
    """List all loaded ONNX models with their input/output shapes."""
    registry = request.app.state.registry
    return {"models": registry.list_models()}


@router.post("/predict", response_model=PredictResponse)
async def predict(req: PredictRequest, request: Request):
    """
    Single-sample prediction. The request is queued and batched
    automatically with other concurrent requests.
    """
    engine   = request.app.state.engine
    registry = request.app.state.registry

    model_name = req.model_name or (
        registry.default_model().name if registry.default_model() else None
    )
    if model_name is None:
        raise HTTPException(status_code=503, detail="No models loaded")

    inputs = np.array(req.inputs, dtype=np.float32)

    t0 = time.monotonic()
    try:
        result = await engine.predict(model_name, inputs)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    latency_ms = (time.monotonic() - t0) * 1000

    return PredictResponse(
        model_name=model_name,
        predictions=result.tolist(),
        latency_ms=round(latency_ms, 3),
    )


@router.post("/predict/batch", response_model=BatchPredictResponse)
async def predict_batch(req: BatchPredictRequest, request: Request):
    """
    Multi-sample batch prediction.
    Each sample is individually queued so the batching engine can
    group them with requests from other callers.
    """
    import asyncio

    engine   = request.app.state.engine
    registry = request.app.state.registry

    model_name = req.model_name or (
        registry.default_model().name if registry.default_model() else None
    )
    if model_name is None:
        raise HTTPException(status_code=503, detail="No models loaded")

    t0 = time.monotonic()

    # Fire all samples concurrently — the engine will group them
    tasks = [
        engine.predict(model_name, np.array(sample, dtype=np.float32))
        for sample in req.inputs
    ]

    try:
        results = await asyncio.gather(*tasks)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    latency_ms = (time.monotonic() - t0) * 1000

    return BatchPredictResponse(
        model_name=model_name,
        predictions=[r.tolist() for r in results],
        batch_size=len(req.inputs),
        latency_ms=round(latency_ms, 3),
    )
