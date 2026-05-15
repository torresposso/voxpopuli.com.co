#!/bin/bash
set -e

# Link the persistent database and uploads if they exist in /data
# But ONLY if we are not in a local dev environment with bind mounts
if [ ! -L "web/app/uploads" ]; then
    if [ -d "/data/uploads" ]; then
        echo "Linking web/app/uploads to /data/uploads..."
        # If there's a local uploads folder, move it to backup first
        if [ -d "web/app/uploads" ] && [ ! -L "web/app/uploads" ]; then
            echo "Moving existing local web/app/uploads to /data (backup)..."
            mv web/app/uploads web/app/uploads.bak.$(date +%s) || true
        fi
        ln -snf /data/uploads web/app/uploads
    fi
fi

if [ ! -L "web/app/database" ]; then
    if [ -d "/data/database" ]; then
        echo "Linking web/app/database to /data/database..."
        # If there's a local database folder, move it to backup first
        if [ -d "web/app/database" ] && [ ! -L "web/app/database" ]; then
            echo "Moving existing local web/app/database to /data (backup)..."
            mv web/app/database web/app/database.bak.$(date +%s) || true
        fi
        ln -snf /data/database web/app/database
    fi
fi

# Ensure SQLite WAL mode is enabled for performance if the DB exists
if [ -f "web/app/database/.ht.sqlite" ]; then
    echo "Enabling SQLite WAL mode and optimizations..."
    php -r "
        try {
            \$db = new PDO('sqlite:web/app/database/.ht.sqlite');
            \$db->exec('PRAGMA journal_mode=WAL;');
            \$db->exec('PRAGMA journal_size_limit = 67108864;');
            \$db->exec('PRAGMA synchronous=NORMAL;');
        } catch (Exception \$e) {
            echo 'Warning: Could not enable optimizations: ' . \$e->getMessage();
        }
    "
fi

# Run optimizations if WordPress is ready
if [ -f "web/wp-config.php" ] || [ -f "web/wp/wp-load.php" ]; then
    echo "Running Acorn optimization..."
    wp acorn optimize > /dev/null 2>&1 || true
    
    echo "Enabling Redis Object Cache..."
    wp redis enable > /dev/null 2>&1 || true
fi

exec "$@"
