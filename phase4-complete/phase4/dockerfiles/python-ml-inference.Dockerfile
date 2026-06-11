# dockerfiles/python-ml-inference.Dockerfile
FROM python:3.12-slim AS deps
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim AS test
WORKDIR /app
COPY --from=deps /install /usr/local
COPY . .
RUN pip install --no-cache-dir pytest pytest-asyncio httpx && pytest tests/ -v

FROM gcr.io/distroless/python3-debian12:nonroot AS runtime
WORKDIR /app
COPY --from=deps /install/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY app/ ./app/
EXPOSE 8100
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8100", "--workers", "2"]
