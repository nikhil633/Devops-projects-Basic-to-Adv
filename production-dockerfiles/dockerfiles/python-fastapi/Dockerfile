# ============================================================
# Python FastAPI — Production Dockerfile
# ============================================================
# FastAPI is async — Uvicorn is the ASGI server.
# For production with multiple workers, use Gunicorn as the
# process manager with Uvicorn workers:
#   Gunicorn manages worker lifecycle (restarts crashed workers)
#   Uvicorn handles async I/O within each worker
#
# Build:  docker build -t my-fastapi-app .
# Run:    docker run -p 8000:8000 my-fastapi-app
# ============================================================

# ── Stage 1: dependencies ─────────────────────────────────
FROM python:3.12-slim AS deps

WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libpq-dev \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: test ─────────────────────────────────────────
# Run tests before building the final image.
# If tests fail → image is NOT built → broken code never ships.
FROM python:3.12-slim AS test

WORKDIR /app
COPY --from=deps /install /usr/local
COPY . .

RUN pip install --no-cache-dir pytest pytest-asyncio httpx \
 && pytest tests/ -v --tb=short


# ── Stage 3: runtime ──────────────────────────────────────
# distroless Python has no shell, no pip, no apt — minimal attack surface
FROM gcr.io/distroless/python3-debian12:nonroot AS runtime

WORKDIR /app

# Copy installed packages from deps stage
COPY --from=deps /install/lib/python3.12/site-packages \
                 /usr/local/lib/python3.12/site-packages
COPY --from=deps /install/bin /usr/local/bin

# Copy only the application source (not tests, not dev files)
COPY app/ ./app/

EXPOSE 8000

# distroless/nonroot runs as UID 65532 by default — no root

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# ── Uvicorn configuration ─────────────────────────────────
# --workers 4      : 4 worker processes (CPU-bound work)
#                    For pure async I/O services: 1 worker per CPU is fine
# --loop uvloop    : faster event loop (C-based, 2–5x faster than asyncio default)
# --http httptools : faster HTTP parsing (C-based)
# --no-access-log  : remove for debugging, keep off in prod (use Prometheus instead)
CMD ["gunicorn", \
     "app.main:app", \
     "--workers", "4", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--bind", "0.0.0.0:8000", \
     "--timeout", "120", \
     "--graceful-timeout", "10", \
     "--access-logfile", "-", \
     "--error-logfile", "-"]
