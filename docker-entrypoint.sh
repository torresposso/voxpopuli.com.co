#!/bin/sh
set -e

# 1. Seguridad: Verificar que el volumen esté montado o sea accesible
if [ ! -d "/data" ]; then
    echo "CRITICAL: /data directory not found. Volume mount might have failed."
    exit 1
fi

# 2. Asegurar directorios en el volumen (Ignoramos errores si ya existen o son de solo lectura)
mkdir -p /data/database /data/uploads 2>/dev/null || true

# 3. Inicialización (Solo copiar si el volumen está vacío)
# Usamos un flag para evitar chequeos de permisos lentos
if [ -d "web/app/database" ] && [ -z "$(ls -A /data/database 2>/dev/null)" ]; then
    echo "Initializing database in /data/database..."
    cp -a web/app/database/. /data/database/ 2>/dev/null || true
fi

if [ -d "web/app/uploads" ] && [ -z "$(ls -A /data/uploads 2>/dev/null)" ]; then
    echo "Initializing uploads in /data/uploads..."
    cp -a web/app/uploads/. /data/uploads/ 2>/dev/null || true
fi

# 4. Enlazar (Removemos locales y creamos symlinks)
# Como somos usuario 82, /app es nuestro, podemos borrar y crear links
rm -rf web/app/database web/app/uploads
ln -s /data/database web/app/database
ln -s /data/uploads web/app/uploads

# 5. Optimización: Habilitar WAL mode si la DB existe
if [ -f "/data/database/.ht.sqlite" ]; then
    echo "Enabling SQLite WAL mode for performance..."
    # Usamos -n para no cargar archivos de config si causan warnings, 
    # pero aquí necesitamos PDO. Los warnings de 'already loaded' deberían haber bajado.
    php -r "
        try {
            \$db = new PDO('sqlite:/data/database/.ht.sqlite');
            \$db->exec('PRAGMA journal_mode=WAL;');
            \$db->exec('PRAGMA synchronous=NORMAL;');
        } catch (Exception \$e) {
            echo 'Warning: Could not enable WAL mode: ' . \$e->getMessage();
        }
    " || true
fi

# 6. Acorn Optimize (Solo en producción)
if [ "$WP_ENV" = "production" ]; then
    echo "Running Acorn optimization..."
    # Ejecutamos desde el root de la app para que WP-CLI encuentre el bootstrap
    wp acorn optimize --path=/app/web --allow-root || echo "Warning: Acorn optimize failed, continuing anyway..."
fi

exec "$@"
