#!/bin/sh
set -e

# 1. Seguridad: Verificar que el volumen esté montado
if ! mountpoint -q /data; then
    echo "CRITICAL: /data is not a mountpoint. Aborting to prevent data inconsistency."
    exit 1
fi

# 2. Asegurar directorios en el volumen
mkdir -p /data/database
mkdir -p /data/uploads
chown -R 82:82 /data/database /data/uploads

# 3. Inicialización (Solo copiar si el volumen está vacío)
if [ -z "$(ls -A /data/database)" ] && [ -d "web/app/database" ]; then
    echo "Initializing database in /data/database..."
    cp -a web/app/database/. /data/database/
fi

if [ -z "$(ls -A /data/uploads)" ] && [ -d "web/app/uploads" ]; then
    echo "Initializing uploads in /data/uploads..."
    cp -a web/app/uploads/. /data/uploads/
fi

# 4. Enlazar (Si no son symlinks, los removemos solo si están vacíos o si estamos seguros del montaje)
# Removemos los locales para montar los symlinks del volumen persistente
# (Asegurado por el chequeo de mountpoint al inicio)
rm -rf web/app/database web/app/uploads
ln -s /data/database web/app/database
ln -s /data/uploads web/app/uploads

# 5. Optimización: Habilitar WAL mode si la DB existe
if [ -f "/data/database/.ht.sqlite" ]; then
    echo "Enabling SQLite WAL mode for performance..."
    php -r "
        \$db = new PDO('sqlite:/data/database/.ht.sqlite');
        \$db->exec('PRAGMA journal_mode=WAL;');
        \$db->exec('PRAGMA synchronous=NORMAL;');
    " || true
fi

exec "$@"
