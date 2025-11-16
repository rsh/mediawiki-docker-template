#!/bin/bash
# MediaWiki Restore Script
# Restores a MediaWiki backup to the instance/ directory
#
# Usage:
#   ./restore-backup.sh <backup-file.tar.gz> [base_directory]
#
# If no base directory is provided, uses current directory
# Restores all data into base_directory/instance/
#
# This script will:
# 1. Stop running Docker containers
# 2. Remove existing data from instance/ (with confirmation via clean.sh)
# 3. Extract the backup into instance/
# 4. Optionally update LocalSettings.php for dev

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <backup-file.tar.gz> [base_directory]"
    echo "Example: $0 ~/Backups/mediawiki-backup-20250120_123456.tar.gz"
    echo "Example: $0 ~/Backups/mediawiki-backup-20250120_123456.tar.gz /path/to/my-wiki"
    exit 1
fi

BACKUP_FILE="$1"
BASE_DIR="${2:-.}"

# Convert backup file to absolute path before changing directories
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi
BACKUP_FILE_ABS=$(cd "$(dirname "$BACKUP_FILE")" && pwd)/$(basename "$BACKUP_FILE")

echo "=========================================="
echo "MediaWiki Restore Script"
echo "=========================================="
echo "Backup file: $BACKUP_FILE_ABS"
echo "Base directory: $(cd "$BASE_DIR" && pwd)"
echo ""

# Create base directory if it doesn't exist
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"
BASE_DIR_ABS=$(pwd)
INSTANCE_DIR="$BASE_DIR_ABS/instance"

# Step 1 & 2: Clean existing data (stop containers + remove files from instance/)
# Check if there's anything to clean in instance/
if [ -d "$INSTANCE_DIR" ] && [ -n "$(ls -A "$INSTANCE_DIR" 2>/dev/null)" ]; then
    # Check if clean.sh exists
    CLEAN_SCRIPT=""
    if [ -f "clean.sh" ]; then
        CLEAN_SCRIPT="./clean.sh"
    elif [ -f "$(dirname "$0")/clean.sh" ]; then
        CLEAN_SCRIPT="$(dirname "$0")/clean.sh"
    fi

    if [ -n "$CLEAN_SCRIPT" ]; then
        echo "Running clean script to prepare for restore..."
        echo ""
        "$CLEAN_SCRIPT" "$BASE_DIR_ABS"
        CLEAN_EXIT=$?
        if [ $CLEAN_EXIT -ne 0 ]; then
            echo "Clean cancelled or failed. Restore aborted."
            exit $CLEAN_EXIT
        fi
    else
        echo "⚠️  WARNING: clean.sh not found. Cannot clean existing data safely."
        echo "Please run clean.sh manually or remove instance/ directory before restoring."
        exit 1
    fi
fi

# Create instance directory
mkdir -p "$INSTANCE_DIR"

# Extract backup into instance/ directory
echo "Extracting backup into instance/..."
tar -xzf "$BACKUP_FILE_ABS" -C "$INSTANCE_DIR"

echo ""
echo "Verifying restored files in instance/..."

RESTORED_COUNT=0

if [ -f "$INSTANCE_DIR/LocalSettings.php" ]; then
    echo "✓ instance/LocalSettings.php"
    RESTORED_COUNT=$((RESTORED_COUNT + 1))
else
    echo "✗ instance/LocalSettings.php not found!"
fi

if [ -d "$INSTANCE_DIR/db" ]; then
    DB_SIZE=$(du -sh "$INSTANCE_DIR/db" 2>/dev/null | cut -f1 || echo "unknown")
    echo "✓ instance/db/ directory (MariaDB, $DB_SIZE)"
    RESTORED_COUNT=$((RESTORED_COUNT + 1))
elif [ -d "$INSTANCE_DIR/data" ]; then
    DB_SIZE=$(du -sh "$INSTANCE_DIR/data" 2>/dev/null | cut -f1 || echo "unknown")
    echo "✓ instance/data/ directory (SQLite, $DB_SIZE)"
    RESTORED_COUNT=$((RESTORED_COUNT + 1))
fi

if [ -d "$INSTANCE_DIR/images" ]; then
    IMG_COUNT=$(find "$INSTANCE_DIR/images" -type f 2>/dev/null | wc -l)
    IMG_SIZE=$(du -sh "$INSTANCE_DIR/images" 2>/dev/null | cut -f1 || echo "unknown")
    echo "✓ instance/images/ directory ($IMG_COUNT files, $IMG_SIZE)"
    RESTORED_COUNT=$((RESTORED_COUNT + 1))
fi

if [ -d "$INSTANCE_DIR/extensions" ]; then
    echo "✓ instance/extensions/ directory"
    RESTORED_COUNT=$((RESTORED_COUNT + 1))
fi

if [ -d "$INSTANCE_DIR/skins" ]; then
    echo "✓ instance/skins/ directory"
    RESTORED_COUNT=$((RESTORED_COUNT + 1))
fi

# Note: Ignore any compose files from the backup - we use our own at repo root

# Set proper permissions and ownership
echo ""
echo "Setting permissions and ownership..."

# LocalSettings.php - readable by web server
chmod 644 "$INSTANCE_DIR/LocalSettings.php" 2>/dev/null || true

# Get current user for ownership
CURRENT_USER=$(id -u)

# Database directories - MariaDB needs write access (UID 999)
# Keep your user as owner, set group to mysql UID, allow group read/write
if [ -d "$INSTANCE_DIR/db" ]; then
    echo "  Setting ownership for db/ (owner: you, group: mysql UID 999)"
    sudo chown -R "$CURRENT_USER:999" "$INSTANCE_DIR/db"
    sudo chmod -R 775 "$INSTANCE_DIR/db"
    sudo find "$INSTANCE_DIR/db" -type f -exec chmod 664 {} \;
fi

if [ -d "$INSTANCE_DIR/data" ]; then
    echo "  Setting ownership for data/ (owner: you, group: mysql UID 999)"
    sudo chown -R "$CURRENT_USER:999" "$INSTANCE_DIR/data"
    sudo chmod -R 775 "$INSTANCE_DIR/data"
    sudo find "$INSTANCE_DIR/data" -type f -exec chmod 664 {} \;
fi

# Images directory - www-data needs write access (UID 33) for uploads
# Keep your user as owner, set group to www-data UID
if [ -d "$INSTANCE_DIR/images" ]; then
    echo "  Setting ownership for images/ (owner: you, group: www-data UID 33)"
    sudo chown -R "$CURRENT_USER:33" "$INSTANCE_DIR/images"
    # Directories need to be writable by owner and group
    sudo find "$INSTANCE_DIR/images" -type d -exec chmod 775 {} \;
    # Files should be readable/writable by owner and group
    sudo find "$INSTANCE_DIR/images" -type f -exec chmod 664 {} \;
fi

# Extensions and skins - www-data needs read access
if [ -d "$INSTANCE_DIR/extensions" ]; then
    echo "  Setting ownership for extensions/ (owner: you, group: www-data UID 33)"
    sudo chown -R "$CURRENT_USER:33" "$INSTANCE_DIR/extensions"
    sudo chmod -R 755 "$INSTANCE_DIR/extensions"
fi

if [ -d "$INSTANCE_DIR/skins" ]; then
    echo "  Setting ownership for skins/ (owner: you, group: www-data UID 33)"
    sudo chown -R "$CURRENT_USER:33" "$INSTANCE_DIR/skins"
    sudo chmod -R 755 "$INSTANCE_DIR/skins"
fi

echo ""
echo "=========================================="
echo "Restore completed successfully!"
echo "=========================================="
echo "Restored $RESTORED_COUNT components"
echo ""

# Step 4: Offer to update LocalSettings.php for development
# Load .env to get DEV_PORT (use default if .env doesn't exist)
DEV_PORT=8080
if [ -f "$BASE_DIR_ABS/.env" ]; then
    # shellcheck source=/dev/null
    source "$BASE_DIR_ABS/.env"
    DEV_PORT=${DEV_PORT:-8080}
fi

if [ -f "$INSTANCE_DIR/LocalSettings.php" ]; then
    CURRENT_SERVER=$(grep "^\\\$wgServer" "$INSTANCE_DIR/LocalSettings.php" | head -1 || echo "")
    echo "Current \$wgServer setting:"
    echo "  $CURRENT_SERVER"
    echo ""
    read -p "Update LocalSettings.php for local development (http://localhost:$DEV_PORT)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Update $wgServer to localhost with DEV_PORT
        if grep -q "^\\\$wgServer" "$INSTANCE_DIR/LocalSettings.php"; then
            sed -i "s|^\\\$wgServer.*|\$wgServer = \"http://localhost:$DEV_PORT\";|" "$INSTANCE_DIR/LocalSettings.php"
            echo "✓ Updated \$wgServer to http://localhost:$DEV_PORT"
        else
            echo "\$wgServer = \"http://localhost:$DEV_PORT\";" >> "$INSTANCE_DIR/LocalSettings.php"
            echo "✓ Added \$wgServer = \"http://localhost:$DEV_PORT\""
        fi
        echo ""
    fi
fi

echo "Next steps:"
echo "1. Start MediaWiki:"
echo "   - Local: docker-compose up -d"
echo "   - Production: docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d"
echo "2. Access your wiki at: http://localhost:$DEV_PORT (dev) or your production domain"
echo ""
