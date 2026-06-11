# tests/test_inference.py
import asyncio
import numpy as np
import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from httpx import AsyncClient, ASGITransport

from app.main import app


# ── Fixtures ───────────────────────────────────────────────────────────────

@pytest.fixture
def mock_model():
    model = MagicMock()
    model.name = "demo-linear"
    model.predict.return_value = np.array([[42.0]])
    model.info.return_value = {
        "name": "demo-linear",
        "input_name": "float_input",
        "input_shape": [None, 4],
        "output_name": "variable",
        "output_shape": [None, 1],
    }
    return model


@pytest.fixture
def mock_registry(mock_model):
    registry = MagicMock()
    registry.get.return_value = mock_model
    registry.default_model.return_value = mock_model
    registry.list_models.return_value = [mock_model.info()]
    return registry


# ── BatchEngine unit tests ─────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_batch_engine_single_request(mock_registry, mock_model):
    from app.core.batch_engine import BatchEngine
    from app.core.config import settings

    settings.batch_max_size = 4
    settings.batch_window_ms = 5.0

    engine = BatchEngine(mock_registry)
    await engine.start()

    inputs = np.array([1.0, 2.0, 3.0, 4.0], dtype=np.float32)
    result = await engine.predict("demo-linear", inputs)

    assert result is not None
    assert isinstance(result, np.ndarray)

    await engine.stop()


@pytest.mark.asyncio
async def test_batch_engine_concurrent_requests(mock_registry, mock_model):
    """Verify multiple concurrent requests are grouped into one batch call."""
    from app.core.batch_engine import BatchEngine
    from app.core.config import settings

    settings.batch_max_size = 8
    settings.batch_window_ms = 20.0

    # Return output with same batch size as input
    def batch_predict(inputs):
        return np.ones((len(inputs), 1), dtype=np.float32) * 42.0
    mock_model.predict.side_effect = batch_predict

    engine = BatchEngine(mock_registry)
    await engine.start()

    # Fire 5 concurrent requests — they should be batched together
    inputs = [np.array([float(i)] * 4) for i in range(5)]
    tasks  = [engine.predict("demo-linear", inp) for inp in inputs]
    results = await asyncio.gather(*tasks)

    assert len(results) == 5
    # All should be 42.0 from our mock
    for r in results:
        assert r[0] == pytest.approx(42.0)

    # The model should have been called fewer times than the number of requests
    # (because requests were batched)
    assert mock_model.predict.call_count < 5

    await engine.stop()


@pytest.mark.asyncio
async def test_batch_engine_unknown_model(mock_registry):
    from app.core.batch_engine import BatchEngine

    mock_registry.get.return_value = None  # model not found
    engine = BatchEngine(mock_registry)
    await engine.start()

    inputs = np.array([1.0, 2.0, 3.0, 4.0])

    with pytest.raises(ValueError, match="not found"):
        await engine.predict("nonexistent-model", inputs)

    await engine.stop()


@pytest.mark.asyncio
async def test_batch_engine_queue_full(mock_registry):
    from app.core.batch_engine import BatchEngine
    from app.core.config import settings

    settings.max_queue_depth = 1
    settings.batch_window_ms = 500.0  # slow drain so queue fills

    engine = BatchEngine(mock_registry)
    # Do NOT start the worker — queue fills immediately
    engine._running = False

    inputs = np.array([1.0, 2.0])
    await engine._queue.put(MagicMock())  # fill the queue

    with pytest.raises(RuntimeError, match="queue is full"):
        await engine.predict("demo-linear", inputs)


# ── HTTP API tests ─────────────────────────────────────────────────────────

@pytest.fixture
def app_with_mocks(mock_registry, mock_model):
    """Patch app state to avoid real Redis / ONNX in HTTP tests."""
    from app.core.batch_engine import BatchEngine

    async def fake_predict(model_name, inputs):
        return np.array([42.0])

    engine = MagicMock()
    engine.predict = AsyncMock(side_effect=fake_predict)

    app.state.registry = mock_registry
    app.state.engine   = engine
    return app


@pytest.mark.asyncio
async def test_health_endpoint(app_with_mocks):
    async with AsyncClient(
        transport=ASGITransport(app=app_with_mocks), base_url="http://test"
    ) as client:
        resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
    assert resp.json()["models_loaded"] == 1


@pytest.mark.asyncio
async def test_list_models(app_with_mocks):
    async with AsyncClient(
        transport=ASGITransport(app=app_with_mocks), base_url="http://test"
    ) as client:
        resp = await client.get("/models")
    assert resp.status_code == 200
    assert len(resp.json()["models"]) == 1
    assert resp.json()["models"][0]["name"] == "demo-linear"


@pytest.mark.asyncio
async def test_predict_single(app_with_mocks):
    async with AsyncClient(
        transport=ASGITransport(app=app_with_mocks), base_url="http://test"
    ) as client:
        resp = await client.post("/predict", json={"inputs": [1.0, 2.0, 3.0, 4.0]})
    assert resp.status_code == 200
    data = resp.json()
    assert "predictions" in data
    assert "latency_ms" in data
    assert data["model_name"] == "demo-linear"


@pytest.mark.asyncio
async def test_predict_empty_inputs(app_with_mocks):
    async with AsyncClient(
        transport=ASGITransport(app=app_with_mocks), base_url="http://test"
    ) as client:
        resp = await client.post("/predict", json={"inputs": []})
    assert resp.status_code == 422  # Pydantic validation error


@pytest.mark.asyncio
async def test_predict_batch(app_with_mocks):
    payload = {
        "inputs": [
            [1.0, 2.0, 3.0, 4.0],
            [5.0, 6.0, 7.0, 8.0],
            [9.0, 10.0, 11.0, 12.0],
        ]
    }
    async with AsyncClient(
        transport=ASGITransport(app=app_with_mocks), base_url="http://test"
    ) as client:
        resp = await client.post("/predict/batch", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["batch_size"] == 3
    assert len(data["predictions"]) == 3
