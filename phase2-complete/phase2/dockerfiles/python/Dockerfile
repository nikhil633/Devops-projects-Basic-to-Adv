# ─── Stage 1: deps ────────────────────────────────────────────────────────
# Use a full Python image to compile any C extensions in requirements
FROM python:3.12-slim AS deps

WORKDIR /app

# Install system build deps (needed by some pip packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ─── Stage 2: test ────────────────────────────────────────────────────────
# Run tests inside the build — if tests fail the image won't be built
FROM python:3.12-slim AS test

WORKDIR /app
COPY --from=deps /install /usr/local
COPY . .

RUN pip install --no-cache-dir pytest pytest-asyncio httpx && \
    pytest tests/ -v --tb=short

# ─── Stage 3: runtime ─────────────────────────────────────────────────────
# distroless/python3 has no shell, package manager, or OS tools
# drastically reduces the attack surface
FROM gcr.io/distroless/python3-debian12:nonroot AS runtime

WORKDIR /app

# Copy installed packages from deps stage
COPY --from=deps /install/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=deps /install/bin /usr/local/bin

# Copy only the application source (no tests, no dev files)
COPY app/ ./app/

EXPOSE 8000

# distroless runs as nonroot by default (UID 65532)
# No shell means no exec into container — good for security
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
