# Stage 1: PHP dependencies and WordPress Core
FROM composer:2 AS php_builder
WORKDIR /app
COPY composer.json composer.lock ./
# We need to allow plugins for wordpress-core-installer to work
RUN composer install --no-dev --no-scripts --optimize-autoloader --ignore-platform-reqs

# Stage 2: Theme assets
FROM node:20-alpine AS node_builder
WORKDIR /app
COPY web/app/themes/sage/package.json web/app/themes/sage/package-lock.json* ./web/app/themes/sage/
COPY web/app/themes/sage ./web/app/themes/sage
WORKDIR /app/web/app/themes/sage
RUN npm install && npm run build

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
    zip

WORKDIR /app

# Copy Caddyfile
COPY Caddyfile /etc/caddy/Caddyfile

# Copy application code (excluding things in builder)
COPY . /app

# Copy EVERYTHING from php_builder to ensure WP core and plugins are there
COPY --from=php_builder /app/vendor /app/vendor
COPY --from=php_builder /app/web/wp /app/web/wp
COPY --from=php_builder /app/web/app/plugins /app/web/app/plugins
COPY --from=php_builder /app/web/app/mu-plugins /app/web/app/mu-plugins

# Copy built theme assets
COPY --from=node_builder /app/web/app/themes/sage/public/build /app/web/app/themes/sage/public/build

# Permissions for SQLite
RUN mkdir -p web/app/database && chmod 777 web/app/database
# Ensure uploads folder exists
RUN mkdir -p web/app/uploads && chmod 777 web/app/uploads

ENV PORT=80
EXPOSE 80
