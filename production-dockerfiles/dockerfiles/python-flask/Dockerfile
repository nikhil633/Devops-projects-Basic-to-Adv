# ============================================================
# Python Flask — Production Dockerfile
# ============================================================
# Flask's built-in dev server (flask run / app.run()) is single-threaded
# and not suitable for production. We use Gunicorn as the WSGI server:
#   - Multiple worker processes (handles concurrent requests)
#   - Robust signal handling and graceful restarts
#   - Production-grade logging
#
# Build:  docker build -t my-flask-app .
# Run:    docker run -p 8000:8000 my-flask-app
# ============================================================

# ── Stage 1: dependency install ───────────────────────────
FROM python:3.12-slim AS deps

WORKDIR /app

# Install build tools needed by some Python packages (psycopg2, cryptography, etc.)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gcc \
      libpq-dev \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# --no-cache-dir: don't cache wheel files (saves ~50MB)
# --prefix=/install: install to a dedicated directory for easy copying
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: runtime ──────────────────────────────────────
FROM python:3.12-slim AS runtime

# Install only runtime system deps (no build tools)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libpq5 \
 && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd --uid 10001 --no-create-home --shell /bin/false appuser
USER appuser

WORKDIR /app

# Copy installed packages from deps stage
COPY --chown=appuser --from=deps /install /usr/local

# Copy application source
COPY --chown=appuser app/ ./app/
COPY --chown=appuser wsgi.py ./

EXPOSE 8000

ENV PYTHONUNBUFFERED=1     \
    PYTHONDONTWRITEBYTECODE=1 \
    FLASK_ENV=production

# ── Gunicorn configuration ────────────────────────────────
# --workers        : (2 * CPU_COUNT) + 1 is the standard formula
#                    In Kubernetes, set CPU limit and use: $(( 2 * $(nproc) + 1 ))
# --worker-class   : sync workers for CPU-bound, gevent/gthread for I/O-bound
# --timeout        : kill worker if it doesn't respond within N seconds
# --bind           : listen on all interfaces
# --access-logfile : log to stdout (Kubernetes/Docker collects stdout logs)
# --error-logfile  : stderr for errors
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["gunicorn", \
     "--workers", "4", \
     "--worker-class", "sync", \
     "--timeout", "120", \
     "--bind", "0.0.0.0:8000", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "--log-level", "info", \
     "wsgi:app"]
