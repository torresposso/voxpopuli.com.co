# Stage 1: PHP dependencies
FROM composer:2 AS php_builder
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs

# Stage 2: Theme assets
FROM node:20-alpine AS node_builder
WORKDIR /app
COPY web/app/themes/sage/package.json web/app/themes/sage/package-lock.json* ./web/app/themes/sage/
COPY web/app/themes/sage ./web/app/themes/sage
WORKDIR /app/web/app/themes/sage
RUN npm install && npm run build

# Stage 3: Runtime
FROM dunglas/frankenphp:latest-php8.3-alpine AS runtime

# Install system extensions
RUN install-php-extensions \
    bcmath \
    exif \
    gd \
    intl \
    mysqli \
    opcache \
    pdo_mysql \
    zip

WORKDIR /app

# Copy Caddyfile to the default location for FrankenPHP
COPY Caddyfile /etc/caddy/Caddyfile

# Copy application code
COPY . /app
COPY --from=php_builder /app/vendor /app/vendor
COPY --from=node_builder /app/web/app/themes/sage/public/build /app/web/app/themes/sage/public/build

# Permissions for SQLite
RUN mkdir -p web/app/database && chmod 777 web/app/database

ENV PORT=80
EXPOSE 80

# FrankenPHP handles the start automatically using /etc/caddy/Caddyfile
