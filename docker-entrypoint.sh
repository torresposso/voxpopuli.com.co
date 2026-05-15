#!/bin/sh
set -e

# Ensure persistent directories exist in the Railway volume
mkdir -p /data/database
mkdir -p /data/uploads

# Set permissions for the volume directories
# (777 is a bit loose but ensures FrankenPHP can write regardless of UID)
chmod 777 /data/database
chmod 777 /data/uploads

# Handle the database directory
if [ -d "web/app/database" ] && [ ! -L "web/app/database" ]; then
    # If it's a real directory, move existing contents to /data if /data is empty
    if [ "$(ls -A /data/database)" ]; then
        echo "Railway volume /data/database is not empty, skipping initial copy."
    else
        echo "Copying initial database files to /data/database..."
        cp -a web/app/database/. /data/database/ || true
    fi
    rm -rf web/app/database
fi

# Symlink persistent folders to the app structure
if [ ! -L "web/app/database" ]; then
    ln -s /data/database web/app/database
fi

if [ -d "web/app/uploads" ] && [ ! -L "web/app/uploads" ]; then
    if [ "$(ls -A /data/uploads)" ]; then
         echo "Railway volume /data/uploads is not empty, skipping initial copy."
    else
        echo "Copying initial uploads to /data/uploads..."
        cp -a web/app/uploads/. /data/uploads/ || true
    fi
    rm -rf web/app/uploads
fi

if [ ! -L "web/app/uploads" ]; then
    ln -s /data/uploads web/app/uploads
fi

# Optimization: Attempt to enable WAL mode on the SQLite DB if it exists
if [ -f "/data/database/.ht.sqlite" ]; then
    echo "Enabling SQLite WAL mode for performance..."
    php -r "
        \$db = new PDO('sqlite:/data/database/.ht.sqlite');
        \$db->exec('PRAGMA journal_mode=WAL;');
        \$db->exec('PRAGMA synchronous=NORMAL;');
    " || echo "Could not enable WAL mode (might be initial install)."
fi

# Execute the main command
exec "$@"
