# app/core/batch_engine.py
#
# BatchEngine — groups concurrent inference requests into batches.
#
# How it works:
#   1. An HTTP handler calls engine.predict(model_name, inputs)
#      which creates an asyncio.Future and puts it in the queue.
#   2. The _worker task runs in a loop:
#        a. Wait for the first item in the queue (or until idle)
#        b. Drain up to BATCH_MAX_SIZE items within BATCH_WINDOW_MS
#        c. Stack all inputs into a single numpy array
#        d. Run one ONNX inference call
#        e. Slice the output and resolve each Future
#   3. The HTTP handler awaits its Future and returns when done.
#
# Result: requests that arrive within the same BATCH_WINDOW_MS
# are automatically grouped and processed together.

import asyncio
import logging
import time
from dataclasses import dataclass, field
from typing import Any, List

import numpy as np
from prometheus_client import Counter, Histogram, Gauge

from app.core.config import settings
from app.core.model_registry import ModelRegistry

logger = logging.getLogger(__name__)

# ── Metrics ────────────────────────────────────────────────────────────────
INFERENCE_TOTAL = Counter(
    "ml_inference_requests_total",
    "Total inference requests",
    ["model", "status"],
)
BATCH_SIZE_HIST = Histogram(
    "ml_batch_size",
    "Distribution of batch sizes",
    buckets=[1, 2, 4, 8, 16, 32, 64],
)
INFERENCE_LATENCY = Histogram(
    "ml_inference_latency_seconds",
    "Model inference latency",
    ["model"],
    buckets=[.001, .005, .01, .025, .05, .1, .25, .5, 1.0],
)
QUEUE_DEPTH = Gauge(
    "ml_queue_depth",
    "Current inference queue depth",
)


@dataclass
class InferenceRequest:
    model_name: str
    inputs:     np.ndarray         # shape: (n_features,) for single, (n, features) for batch
    future:     asyncio.Future     # resolved with ndarray of predictions
    received_at: float = field(default_factory=time.monotonic)


class BatchEngine:
    def __init__(self, registry: ModelRegistry):
        self.registry = registry
        self._queue:  asyncio.Queue  = asyncio.Queue(maxsize=settings.max_queue_depth)
        self._worker_task: asyncio.Task | None = None
        self._running = False

    async def start(self):
        self._running = True
        self._worker_task = asyncio.create_task(self._worker_loop())
        logger.info(
            "BatchEngine started (max_batch=%d, window_ms=%.1f)",
            settings.batch_max_size,
            settings.batch_window_ms,
        )

    async def stop(self):
        self._running = False
        if self._worker_task:
            self._worker_task.cancel()
            try:
                await self._worker_task
            except asyncio.CancelledError:
                pass

    async def predict(self, model_name: str, inputs: np.ndarray) -> np.ndarray:
        """
        Enqueue an inference request and wait for the result.
        inputs: shape (n_features,) — a single sample
        returns: shape (n_outputs,) — predictions for this sample
        """
        if self._queue.full():
            INFERENCE_TOTAL.labels(model=model_name, status="rejected").inc()
            raise RuntimeError("Inference queue is full — try again later")

        loop   = asyncio.get_event_loop()
        future = loop.create_future()

        req = InferenceRequest(
            model_name=model_name,
            inputs=np.atleast_2d(inputs),  # ensure 2D: (1, n_features)
            future=future,
        )

        await self._queue.put(req)
        QUEUE_DEPTH.set(self._queue.qsize())

        # Wait for the worker to resolve our future
        return await future

    async def _worker_loop(self):
        """Continuously drains the queue in batches."""
        while self._running:
            batch: List[InferenceRequest] = []

            # Block until at least one request arrives
            try:
                first = await asyncio.wait_for(
                    self._queue.get(),
                    timeout=1.0,
                )
                batch.append(first)
            except asyncio.TimeoutError:
                continue  # nothing in queue, loop again

            # Collect more requests up to BATCH_MAX_SIZE within BATCH_WINDOW_MS
            deadline = time.monotonic() + settings.batch_window_ms / 1000.0
            while len(batch) < settings.batch_max_size:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                try:
                    req = await asyncio.wait_for(self._queue.get(), timeout=remaining)
                    batch.append(req)
                except asyncio.TimeoutError:
                    break

            QUEUE_DEPTH.set(self._queue.qsize())

            # Group by model (different models may be in the queue)
            by_model: dict[str, List[InferenceRequest]] = {}
            for req in batch:
                by_model.setdefault(req.model_name, []).append(req)

            for model_name, reqs in by_model.items():
                await self._run_batch(model_name, reqs)

    async def _run_batch(self, model_name: str, reqs: List[InferenceRequest]):
        """Stack inputs, run one ONNX call, slice results back to futures."""
        model = self.registry.get(model_name)
        if model is None:
            err = ValueError(f"Model '{model_name}' not found")
            for req in reqs:
                if not req.future.done():
                    req.future.set_exception(err)
            return

        # Stack all individual inputs into one batch array
        # Each req.inputs is (1, n_features) — stack to (batch_size, n_features)
        batch_input = np.vstack([req.inputs for req in reqs])
        BATCH_SIZE_HIST.observe(len(reqs))

        try:
            t0 = time.monotonic()
            # Run inference in a thread pool — ONNX Runtime releases the GIL
            loop = asyncio.get_event_loop()
            outputs = await loop.run_in_executor(
                None,
                model.predict,
                batch_input,
            )
            elapsed = time.monotonic() - t0
            INFERENCE_LATENCY.labels(model=model_name).observe(elapsed)

            # Slice output back to individual requests
            for i, req in enumerate(reqs):
                if not req.future.done():
                    req.future.set_result(outputs[i])
                INFERENCE_TOTAL.labels(model=model_name, status="success").inc()

            logger.debug(
                "Batch inference: model=%s batch_size=%d latency_ms=%.2f",
                model_name, len(reqs), elapsed * 1000,
            )

        except Exception as exc:
            logger.error("Inference error for model %s: %s", model_name, exc)
            for req in reqs:
                if not req.future.done():
                    req.future.set_exception(exc)
            INFERENCE_TOTAL.labels(model=model_name, status="error").inc()
