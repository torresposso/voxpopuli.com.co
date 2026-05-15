# Stage 1: PHP dependencies (Root + Theme)
FROM composer:2 AS php_builder
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --optimize-autoloader --ignore-platform-reqs --no-interaction --no-ansi

COPY web/app/themes/sage/composer.json web/app/themes/sage/composer.lock* ./web/app/themes/sage/
RUN composer install --working-dir=web/app/themes/sage --no-dev --no-scripts --optimize-autoloader --ignore-platform-reqs --no-interaction --no-ansi

# Stage 2: Theme assets (Vite)
FROM node:20-alpine AS node_builder
WORKDIR /app/web/app/themes/sage
COPY web/app/themes/sage/package.json web/app/themes/sage/package-lock.json* ./
RUN npm ci --quiet
COPY web/app/themes/sage ./
RUN npm run build

# Stage 3: Runtime
FROM dunglas/frankenphp:latest-alpine AS runtime

# Labels for better image management
LABEL maintainer="Vox Populi Digital <dev@voxpopuli.digital>" \
      description="Optimized Bedrock WordPress stack for Vox Populi"

# Install WP-CLI (Most extensions are already in FrankenPHP base)
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

WORKDIR /app

# Global PHP/FrankenPHP settings
ENV PORT=8080 \
    PHP_INI_SCAN_DIR=:/usr/local/etc/php/conf.d \
    # OpCache Production Settings
    PHP_OPCACHE_MEMORY_CONSUMPTION=192 \
    PHP_OPCACHE_INTERNED_STRINGS_BUFFER=16 \
    PHP_OPCACHE_MAX_ACCELERATED_FILES=10000 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    PHP_OPCACHE_ENABLE_CLI=1 \
    # Caddy Non-Root storage
    XDG_DATA_HOME=/tmp/caddy_data \
    XDG_CONFIG_HOME=/tmp/caddy_config


# Copy infrastructure config
COPY Caddyfile /etc/caddy/Caddyfile
COPY php.ini /usr/local/etc/php/conf.d/app-optimized.ini

# Copy application code structure first (to leverage cache)
COPY . /app

# Bring in dependencies and built assets
COPY --from=php_builder /app/vendor /app/vendor
COPY --from=php_builder /app/web/wp /app/web/wp
COPY --from=php_builder /app/web/app/plugins /app/web/app/plugins
COPY --from=php_builder /app/web/app/themes/sage/vendor /app/web/app/themes/sage/vendor
COPY --from=node_builder /app/web/app/themes/sage/public/build /app/web/app/themes/sage/public/build

# Final setup: drop-ins, directories and permissions
RUN cp /app/web/app/plugins/redis-cache/includes/object-cache.php /app/web/app/object-cache.php && \
    mkdir -p web/app/database web/app/uploads web/app/mu-plugins && \
    chown -R 82:82 /app && \
    chmod +x /app/docker-entrypoint.sh

# Healthcheck for reliability
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/wp/wp-login.php || exit 1

EXPOSE 8080

# Switch to non-root user
USER 82

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]

