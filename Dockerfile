# Build Sage assets
FROM node:20-alpine AS assets
WORKDIR /app
COPY . .
# If your theme folder is different, adjust this path
RUN if [ -d "web/app/themes/sage" ]; then \
        cd web/app/themes/sage && npm install && npm run build; \
    fi

# Final image
FROM dunglas/frankenphp:1-php8.3-alpine AS runtime

# Set Caddy storage paths explicitly
ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data

# Install su-exec for safe privilege dropping and other essentials
RUN apk add --no-cache \
    su-exec \
    bash \
    curl \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Use production PHP configuration and tune it for performance (low-memory profile)
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" && \
    sed -i 's/memory_limit = 128M/memory_limit = 128M/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 100M/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/post_max_size = 8M/post_max_size = 100M/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/;opcache.enable=1/opcache.enable=1/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/;opcache.validate_timestamps=1/opcache.validate_timestamps=1/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=2/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/;opcache.memory_consumption=128/opcache.memory_consumption=64/' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/;opcache.interned_strings_buffer=8/opcache.interned_strings_buffer=8/' "$PHP_INI_DIR/php.ini"

# Global PHP/FrankenPHP settings
ENV PORT=8080 \
    COMPOSER_ALLOW_SUPERUSER=1

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy application files
COPY . .

# Copy build assets from the assets stage
COPY --from=assets /app/web/app/themes/sage/public/build ./web/app/themes/sage/public/build/

# Setup permissions
RUN chmod +x /app/docker-entrypoint.sh

# Healthcheck for reliability
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8080/wp/wp-login.php || exit 1

EXPOSE 8080

# Run as root to allow entrypoint to fix volume permissions
USER root

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/app/Caddyfile", "--adapter", "caddyfile"]
