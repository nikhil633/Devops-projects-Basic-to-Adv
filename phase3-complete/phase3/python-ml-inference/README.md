# ML Inference API — Python + FastAPI + ONNX Runtime

## Architecture

```
HTTP Request ──► POST /predict
                     │
                     ▼
              BatchEngine.predict()
              (adds Future to queue)
                     │
              asyncio.Queue
                     │
              _worker_loop (background task)
                     │
              ┌──────┴───────┐
              │  Collect up  │  ← waits BATCH_WINDOW_MS or BATCH_MAX_SIZE
              │  to 32 reqs  │
              └──────┬───────┘
                     │
              np.vstack(all inputs)  ← one array: (batch_size, n_features)
                     │
              onnxruntime.InferenceSession.run()  ← ONE call for the whole batch
                     │
              Slice output → resolve each Future
                     │
              HTTP Response returns to each caller
```

## Why batch inference?

ONNX Runtime (and GPU kernels) are dramatically more efficient with batches.
A batch of 32 samples takes ~2ms. 32 individual calls take ~64ms.
The batching engine groups requests that arrive within the same time window automatically — callers don't need to do anything special.

## Run locally

```bash
pip install -r requirements.txt
make run
```

The service auto-creates a demo `linear regression` ONNX model on first startup so you can test immediately.

## Test it

```bash
# Single prediction
curl -X POST http://localhost:8100/predict \
  -H "Content-Type: application/json" \
  -d '{"inputs": [1.0, 2.0, 3.0, 4.0]}'

# Batch prediction (3 samples)
curl -X POST http://localhost:8100/predict/batch \
  -H "Content-Type: application/json" \
  -d '{"inputs": [[1,2,3,4],[5,6,7,8],[9,10,11,12]]}'

# List models
curl http://localhost:8100/models
```

## Using your own ONNX model

```bash
# Place any .onnx file in the models directory
cp my_model.onnx app/models/

# Restart the service — it auto-discovers all .onnx files
make run

# Predict with your model
curl -X POST http://localhost:8100/predict \
  -H "Content-Type: application/json" \
  -d '{"inputs": [1.0, 2.0, 3.0], "model_name": "my_model"}'
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /models | List loaded ONNX models |
| POST | /predict | Single-sample inference |
| POST | /predict/batch | Multi-sample batch inference |
| GET | /health | Health check |
| GET | /metrics | Prometheus metrics |

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| BATCH_MAX_SIZE | 32 | Max requests per batch |
| BATCH_WINDOW_MS | 10 | Max wait ms before flushing |
| MAX_QUEUE_DEPTH | 1000 | Backpressure limit |
| MODELS_DIR | app/models | Directory with .onnx files |
| REDIS_URL | redis://localhost:6379 | Redis connection |
