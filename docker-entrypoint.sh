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

# 4. Enlazar (Solo si no son links ya)
# Usamos [ -L ] para chequear si es un link simbólico y evitar borrar datos por error
for dir in "web/app/database" "web/app/uploads"; do
    if [ ! -L "$dir" ]; then
        if [ -d "$dir" ] && [ "$(ls -A /data/$(basename $dir) 2>/dev/null)" ]; then
            echo "Moving existing local $dir to /data (backup)..."
            mv "$dir" "$dir.bak" || true
        else
            rm -rf "$dir"
        fi
        echo "Creating symlink for $dir..."
        ln -s "/data/$(basename $dir)" "$dir"
    fi
done

# 5. Optimización: Habilitar WAL mode si la DB existe
if [ -f "/data/database/.ht.sqlite" ]; then
    echo "Enabling SQLite WAL mode for performance..."
    # Usamos -n para no cargar archivos de config si causan warnings, 
    # pero aquí necesitamos PDO. Los warnings de 'already loaded' deberían haber bajado.
    php -r "
        try {
            \$db = new PDO('sqlite:/data/database/.ht.sqlite');
            \$db->exec('PRAGMA journal_mode=WAL;');
            \$db->exec('PRAGMA journal_size_limit = 67108864;');
            \$db->exec('PRAGMA synchronous=NORMAL;');
        } catch (Exception \$e) {
            echo 'Warning: Could not enable WAL mode: ' . \$e->getMessage();
        }
    " || true
fi

# 6. Acorn Optimize (Solo si WP está configurado y en producción)
if [ "$WP_ENV" = "production" ] && [ -f "web/wp-config.php" ]; then
    echo "Running Acorn optimization..."
    # Intentamos optimizar, pero silenciamos el output de error si Acorn no está listo aún
    wp acorn optimize --path=/app/web --allow-root >/dev/null 2>&1 || true
fi

exec "$@"
