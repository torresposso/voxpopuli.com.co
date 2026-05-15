# Build Sage assets
FROM node:20-alpine AS assets
WORKDIR /app
COPY . .
# If your theme folder is different, adjust this path
RUN if [ -d "web/app/themes/sage" ]; then \
        cd web/app/themes/sage && npm install && npm run build; \
    fi

# Build Composer dependencies
FROM composer:latest AS composer
WORKDIR /app
COPY composer.json composer.lock ./
# Install dependencies including WordPress core
RUN composer install --no-dev --no-interaction --optimize-autoloader --no-scripts

# Final image
FROM dunglas/frankenphp:1-php8.3-alpine AS runtime

# Set Caddy storage paths explicitly
ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data \
    PORT=80 \
    COMPOSER_ALLOW_SUPERUSER=1

# Install system dependencies
RUN apk add --no-cache \
    su-exec \
    bash \
    curl \
    libcap \
    && install-php-extensions \
    pdo_sqlite \
    gd \
    intl \
    opcache \
    redis \
    zip \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Copy Composer from official image (for runtime usage like wp acorn)
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Copy dependencies from composer stage
COPY --from=composer /app/vendor ./vendor/
COPY --from=composer /app/web/wp ./web/wp/

# Use production PHP configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" && \
    sed -i 's/memory_limit = 128M/memory_limit = 128M/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 100M/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/post_max_size = 8M/post_max_size = 100M/' "$PHP_INI_DIR/php.ini"

# Copy the rest of the app
COPY . .

# Run scripts now that all files are present (Acorn, etc.)
RUN composer install --no-dev --no-interaction --optimize-autoloader

# Copy assets from assets stage
COPY --from=assets /app/web/app/themes/sage/public/build ./web/app/themes/sage/public/build/

RUN chmod +x /app/docker-entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:80/wp/wp-login.php || exit 1

EXPOSE 80

USER root
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/app/Caddyfile", "--adapter", "caddyfile"]
