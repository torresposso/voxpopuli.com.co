# Stage 1: PHP dependencies
FROM composer:2 AS php_builder
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs

# Stage 2: Theme assets
FROM node:20-alpine AS node_builder
WORKDIR /app
# Copy only theme files needed for build
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

# Set workdir
WORKDIR /app

# Copy application code
COPY . /app

# Copy PHP dependencies
COPY --from=php_builder /app/vendor /app/vendor

# Copy built theme assets
COPY --from=node_builder /app/web/app/themes/sage/public/build /app/web/app/themes/sage/public/build

# Ensure SQLite directory exists and has permissions
RUN mkdir -p web/app/database && chmod 777 web/app/database

# FrankenPHP configuration
ENV FRANKENPHP_CONFIG="worker ./web/index.php"
ENV RAILPACK_PHP_ROOT_DIR=/app/web
