# Stage 1: PHP dependencies (Root + Theme)
FROM composer:2 AS php_builder
WORKDIR /app

# Install root dependencies
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --optimize-autoloader --ignore-platform-reqs

# Install theme dependencies
COPY web/app/themes/sage/composer.json web/app/themes/sage/composer.lock* ./web/app/themes/sage/
RUN composer install --working-dir=web/app/themes/sage --no-dev --no-scripts --optimize-autoloader --ignore-platform-reqs

# Stage 2: Theme assets (Vite)
FROM node:20-alpine AS node_builder
WORKDIR /app/web/app/themes/sage
# Copy only package files first to leverage Docker layer caching
COPY web/app/themes/sage/package.json web/app/themes/sage/package-lock.json* ./
RUN npm ci || npm install

# Copy the rest of the theme to build assets
COPY web/app/themes/sage ./
RUN npm run build

# Stage 3: Runtime
FROM dunglas/frankenphp:latest-php8.3-alpine AS runtime

RUN install-php-extensions \
    bcmath \
    exif \
    gd \
    intl \
    mysqli \
    opcache \
    pdo_mysql \
    redis \
    zip

WORKDIR /app

# Copy Caddyfile
COPY Caddyfile /etc/caddy/Caddyfile

# Copy optimized PHP config
COPY php.ini /usr/local/etc/php/conf.d/app-optimized.ini

# Copy application code (protected by .dockerignore)
COPY . /app

# Copy EVERYTHING from php_builder
COPY --from=php_builder /app/vendor /app/vendor
COPY --from=php_builder /app/web/wp /app/web/wp
COPY --from=php_builder /app/web/app/plugins /app/web/app/plugins
COPY --from=php_builder /app/web/app/themes/sage/vendor /app/web/app/themes/sage/vendor

# Copy built theme assets
COPY --from=node_builder /app/web/app/themes/sage/public/build /app/web/app/themes/sage/public/build

# Final production settings
RUN mkdir -p web/app/database web/app/uploads web/app/mu-plugins && \
    chown -R 82:82 web/app/database web/app/uploads web/app/mu-plugins && \
    chmod +x docker-entrypoint.sh

ENV PORT=80
EXPOSE 80

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
