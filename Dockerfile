# syntax=docker/dockerfile:1

# ============================================================
# Stage 1: Node dependencies
# ============================================================
FROM node:20-alpine AS node-deps
WORKDIR /theme
COPY web/app/themes/voxpopuli-fundacion/package*.json ./
RUN npm ci

# ============================================================
# Stage 2: Asset build
# ============================================================
FROM node-deps AS build
COPY web/app/themes/voxpopuli-fundacion/ .
RUN npm run build

# ============================================================
# Stage 3: PHP dependencies (Composer)
# ============================================================
FROM composer:2 AS vendor
WORKDIR /app

RUN mkdir -p web/app/mu-plugins web/app/plugins web/app/themes web/wp

COPY composer.json composer.lock ./
COPY web/app/themes/voxpopuli-fundacion/composer.json ./web/app/themes/voxpopuli-fundacion/

ENV COMPOSER_IGNORE_PLATFORM_REQ=ext-*

RUN composer install \
    --no-dev \
    --no-interaction \
    --optimize-autoloader

RUN cd web/app/themes/voxpopuli-fundacion && \
    composer install \
    --no-dev \
    --no-interaction \
    --optimize-autoloader

# ============================================================
# Stage 4: Development (FrankenPHP + tools, non-root)
# ============================================================
FROM dunglas/frankenphp:php8.4-alpine AS dev

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN addgroup -g ${GROUP_ID} appuser \
    && adduser -u ${USER_ID} -G appuser -D appuser

ENV SERVER_NAME=:8080
ENV SERVER_ROOT=/app/web

RUN apk add --no-cache git curl sqlite bash unzip \
    && install-php-extensions gd zip exif mysqli pdo_mysql opcache \
    && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

EXPOSE 8080

RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp \
    && mkdir -p /data/caddy /config/caddy \
    && chown -R appuser:appuser /data/caddy /config/caddy

USER appuser
WORKDIR /app

# ============================================================
# Stage 5: Production (FrankenPHP, self-contained, non-root)
# ============================================================
FROM dunglas/frankenphp:php8.4-bookworm AS prod

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN groupadd -g ${GROUP_ID} appuser \
    && useradd -u ${USER_ID} -g appuser -m -s /bin/bash appuser

RUN install-php-extensions gd zip exif mysqli pdo_mysql opcache \
    && cp $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini

WORKDIR /app

COPY . /app

COPY --from=vendor /app/vendor /app/vendor
COPY --from=vendor /app/web/wp /app/web/wp
COPY --from=vendor /app/web/app/mu-plugins /app/web/app/mu-plugins
COPY --from=vendor /app/web/app/plugins /app/web/app/plugins
COPY --from=vendor /app/web/app/themes/voxpopuli-fundacion/vendor /app/web/app/themes/voxpopuli-fundacion/vendor
COPY --from=build /theme/public /app/web/app/themes/voxpopuli-fundacion/public

COPY --chown=appuser:appuser Caddyfile /etc/frankenphp/Caddyfile
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates wget libcap2-bin; \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.17/gosu-$dpkgArch"; \
    chmod +x /usr/local/bin/gosu; \
    gosu nobody true; \
    wget -O /usr/local/bin/wp "https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"; \
    chmod +x /usr/local/bin/wp; \
    rm -rf /var/lib/apt/lists/*; \
    setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp; \
    mkdir -p /data/caddy /config/caddy /data/database /data/uploads; \
    chown -R appuser:appuser /data/caddy /config/caddy /data; \
    mkdir -p /app/web/app/cache; \
    chown -R appuser:appuser /app/web/app; \
    rm -rf /app/web/app/uploads; \
    ln -s /data/uploads /app/web/app/uploads; \
    chown -h appuser:appuser /app/web/app/uploads

ENV SERVER_ROOT=/app/web
ENV DB_DIR=/data/database
ENV GOMEMLIMIT=1024MiB
ENV GODEBUG=cgocheck=0

EXPOSE 80
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["frankenphp", "run"]
