#!/bin/sh
set -e

if [ "$(id -u)" = "0" ]; then
    if [ ! -f /data/database/.ht.sqlite ] && [ -f /app/storage/database/.ht.sqlite ]; then
        cp -a /app/storage/database/. /data/database/
    fi

    chown -R appuser:appuser /data 2>/dev/null || true

    if [ -f /usr/local/bin/wp ]; then
        echo "=== Warming up Acorn Cache & Optimizations ==="
        gosu appuser wp acorn optimize --allow-root || true
    fi

    exec gosu appuser "$@"
fi

exec "$@"
