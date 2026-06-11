# ============================================================
# Ruby on Rails — Production Dockerfile
# ============================================================
# Rails in production uses:
#   Puma     — multi-threaded Rack-compatible web server
#   Bundler  — gem dependency manager (like pip or npm)
#   Assets   — precompiled via `assets:precompile`
#
# Build:  docker build -t my-rails-app .
# Run:    docker run -p 3000:3000 -e RAILS_MASTER_KEY=xxx my-rails-app
# ============================================================

# ── Stage 1: gem install ──────────────────────────────────
FROM ruby:3.3-slim AS gems

WORKDIR /app

# Build deps for native gem extensions
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      git \
 && rm -rf /var/lib/apt/lists/*

# Copy Gemfiles first (cache layer)
COPY Gemfile Gemfile.lock ./

# --without development test: skip dev/test gems in production
# --jobs 4: parallel gem install
# --retry 3: retry on network failures
RUN bundle config set --local deployment 'true' \
 && bundle config set --local without 'development test' \
 && bundle install --jobs 4 --retry 3


# ── Stage 2: asset precompile ─────────────────────────────
FROM ruby:3.3-slim AS builder

WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libpq-dev \
      nodejs \
      npm \
 && rm -rf /var/lib/apt/lists/*

COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY . .

# Assets must be compiled before the image is finalised
# SECRET_KEY_BASE is required by Rails asset pipeline — dummy value is fine here
ENV RAILS_ENV=production \
    SECRET_KEY_BASE=dummy_for_assets \
    RAILS_SERVE_STATIC_FILES=true

RUN bundle exec rails assets:precompile
# Output: public/assets/


# ── Stage 3: runtime ──────────────────────────────────────
FROM ruby:3.3-slim AS runtime

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libpq5 \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --uid 10001 --no-create-home --shell /bin/false rails
USER rails

WORKDIR /app

COPY --chown=rails:rails --from=gems    /usr/local/bundle  /usr/local/bundle
COPY --chown=rails:rails --from=builder /app               ./

EXPOSE 3000

ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

# ── Required at runtime (set via env or secrets) ──────────
# RAILS_MASTER_KEY    — decrypt credentials.yml.enc
# DATABASE_URL        — postgres://user:pass@host:5432/mydb
# REDIS_URL           — redis://redis:6379 (if using Action Cable / Sidekiq)

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/up || exit 1

# Puma configuration is in config/puma.rb
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
