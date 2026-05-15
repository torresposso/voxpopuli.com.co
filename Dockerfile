# Build Sage assets
FROM node:20-alpine AS assets
WORKDIR /app
COPY . .
# If your theme folder is different, adjust this path
RUN if [ -d "web/app/themes/sage" ]; then \
        cd web/app/themes/sage && npm install && npm run build; \
    fi

# Final image
FROM dunglas/frankenphp:1-php8.3-alpine

# Install necessary PHP extensions for WordPress and SQLite
RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    bash \
    curl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd zip intl mbstring mysqli pdo_mysql bcmath \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Clean up redundant PHP extension configs that cause "already loaded" warnings
RUN rm -f /usr/local/etc/php/conf.d/docker-php-ext-sodium.ini 2>/dev/null || true

# Use production PHP configuration and tune it for performance (low-memory profile)
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" && \
    sed -i 's/memory_limit = 128M/memory_limit = 256M/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 100M/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/post_max_size = 8M/post_max_size = 100M/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/;opcache.enable=1/opcache.enable=1/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/;opcache.validate_timestamps=1/opcache.validate_timestamps=1/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=2/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/;opcache.memory_consumption=128/opcache.memory_consumption=64/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/;opcache.interned_strings_buffer=8/opcache.interned_strings_buffer=8/' "$PHP_INI_DIR/php.ini"

# Global PHP/FrankenPHP settings
ENV PORT=8080 \
    PHP_INI_SCAN_DIR=:/usr/local/etc/php/conf.d \
    COMPOSER_ALLOW_SUPERUSER=1

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy application files
COPY . .

# Copy build assets from the assets stage
COPY --from=assets /app/web/app/themes/sage/public/build ./web/app/themes/sage/public/build

# Setup permissions and entrypoint for non-root (UID 82 = www-data)
RUN chown -R 82:82 /app && \
    chmod +x /app/docker-entrypoint.sh

# Healthcheck for reliability
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8080/wp/wp-login.php || exit 1

EXPOSE 8080

USER 82

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
