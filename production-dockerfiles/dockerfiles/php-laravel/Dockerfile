# ============================================================
# PHP Laravel — Production Dockerfile
# ============================================================
# Laravel production stack:
#   PHP-FPM  — PHP FastCGI Process Manager (handles PHP requests)
#   Nginx    — web server (serves static files, proxies PHP to FPM)
#   Composer — PHP dependency manager
#   Artisan  — Laravel CLI (migrations, cache, queue)
#
# Build:  docker build -t my-laravel-app .
# Run:    docker run -p 80:80 -e APP_KEY=base64:xxx my-laravel-app
# ============================================================

# ── Stage 1: composer install ─────────────────────────────
FROM composer:2.7 AS composer

WORKDIR /app

COPY composer.json composer.lock ./

# --no-dev: skip development packages (phpunit, faker, etc.)
# --optimize-autoloader: generate optimised class map (faster in prod)
# --no-interaction: non-interactive mode
RUN composer install \
      --no-dev \
      --optimize-autoloader \
      --no-interaction \
      --no-scripts \
      --prefer-dist


# ── Stage 2: runtime ──────────────────────────────────────
FROM php:8.3-fpm-alpine AS runtime

# PHP extensions required by Laravel
RUN apk add --no-cache \
      nginx \
      supervisor \
      libpq \
      libpng \
      libjpeg-turbo \
      freetype \
 && docker-php-ext-install \
      pdo \
      pdo_pgsql \
      pdo_mysql \
      opcache \
      bcmath \
      pcntl \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install gd

# PHP production config
COPY docker/php.ini     /usr/local/etc/php/conf.d/production.ini
COPY docker/nginx.conf  /etc/nginx/http.d/default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Non-root user
RUN addgroup -S laravel && adduser -S laravel -G laravel

WORKDIR /var/www/html

# Copy vendor and application
COPY --chown=laravel:laravel --from=composer /app/vendor ./vendor
COPY --chown=laravel:laravel . .

# Bootstrap Laravel
RUN php artisan config:cache \
 && php artisan route:cache \
 && php artisan view:cache

EXPOSE 80

ENV APP_ENV=production \
    LOG_CHANNEL=stderr

# ── Required at runtime ───────────────────────────────────
# APP_KEY     — generate with: php artisan key:generate --show
# DB_HOST, DB_PORT, DB_DATABASE, DB_USERNAME, DB_PASSWORD
# CACHE_DRIVER, SESSION_DRIVER, QUEUE_CONNECTION

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://localhost/up || exit 1

# Supervisor manages both Nginx and PHP-FPM as a single process group
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
