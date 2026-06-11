# ============================================================
# Python Django — Production Dockerfile
# ============================================================
# Django has two serving concerns:
#   1. Dynamic requests: Gunicorn + WSGI (this Dockerfile handles this)
#   2. Static files:     Nginx or S3/CDN (collected via collectstatic)
#
# For production, NEVER use Django's built-in runserver.
# It's single-threaded, single-process, and outputs debug info.
#
# Build:  docker build -t my-django-app .
# Run:    docker run -p 8000:8000 -e DJANGO_SECRET_KEY=xxx my-django-app
# ============================================================

# ── Stage 1: dependencies ─────────────────────────────────
FROM python:3.12-slim AS deps

WORKDIR /app

# System deps needed by common Django packages:
# gcc, libpq-dev: psycopg2 (PostgreSQL driver)
# libjpeg-dev, zlib1g-dev: Pillow (image handling)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gcc \
      libpq-dev \
      libjpeg-dev \
      zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: build (collectstatic) ────────────────────────
# Django's collectstatic gathers all static files into one directory.
# This is required for Whitenoise (inline static file serving) or
# when uploading to S3/CDN during CI.
FROM python:3.12-slim AS builder

WORKDIR /app

COPY --from=deps /install /usr/local

COPY manage.py .
COPY myproject/ ./myproject/
COPY apps/       ./apps/

# Run collectstatic with a dummy secret key
# (SECRET_KEY is only needed at startup, not for collectstatic)
ENV DJANGO_SECRET_KEY=dummy-key-for-collectstatic \
    DJANGO_SETTINGS_MODULE=myproject.settings.production \
    PYTHONUNBUFFERED=1

RUN python manage.py collectstatic --noinput
# Output: /app/staticfiles/


# ── Stage 3: runtime ──────────────────────────────────────
FROM python:3.12-slim AS runtime

# Only runtime system deps
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libpq5 \
      libjpeg62-turbo \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --uid 10001 --no-create-home --shell /bin/false django
USER django

WORKDIR /app

# Copy deps and app
COPY --chown=django --from=deps    /install        /usr/local
COPY --chown=django --from=builder /app            ./

EXPOSE 8000

ENV PYTHONUNBUFFERED=1       \
    PYTHONDONTWRITEBYTECODE=1 \
    DJANGO_SETTINGS_MODULE=myproject.settings.production

# ── Django production checklist ───────────────────────────
# These must be set via environment variables at runtime:
#   DJANGO_SECRET_KEY      — long random string, never commit to source
#   DATABASE_URL           — postgres://user:pass@host:5432/db
#   ALLOWED_HOSTS          — comma-separated list of valid hostnames
#   DEBUG=False            — MUST be False in production

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health/')" || exit 1

CMD ["gunicorn", \
     "myproject.wsgi:application", \
     "--workers", "4", \
     "--worker-class", "sync", \
     "--timeout", "120", \
     "--bind", "0.0.0.0:8000", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "--log-level", "info"]
