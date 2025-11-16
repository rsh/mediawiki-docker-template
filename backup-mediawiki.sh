#!/bin/bash
# MediaWiki Backup Script
# Creates a backup of a local MediaWiki instance from the instance/ directory
#
# Usage:
#   ./backup-mediawiki.sh [base_directory]
#
# If no argument is provided, assumes current directory is the base directory
# Backs up everything from base_directory/instance/
#
# IMPORTANT: Stop Docker containers before running this script to ensure database consistency:
#   docker-compose down

set -e

BASE_DIR="${1:-.}"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mediawiki-backup-${BACKUP_DATE}"
BACKUP_FILE="${BACKUP_NAME}.tar.gz"

# Change to base directory
cd "$BASE_DIR"
BASE_DIR_ABS=$(pwd)
INSTANCE_DIR="$BASE_DIR_ABS/instance"

# Verify instance directory exists
if [ ! -d "$INSTANCE_DIR" ]; then
    echo "Error: instance/ directory not found in $BASE_DIR_ABS"
    echo "Please run this script from your MediaWiki base directory"
    echo "Usage: $0 [base_directory]"
    exit 1
fi

# Verify we have MediaWiki data
if [ ! -f "$INSTANCE_DIR/LocalSettings.php" ]; then
    echo "Error: LocalSettings.php not found in $INSTANCE_DIR"
    echo "The instance/ directory doesn't appear to contain MediaWiki data"
    exit 1
fi

# Check if Docker containers are running
if [ -f "docker-compose.yml" ] && command -v docker-compose >/dev/null 2>&1; then
    RUNNING_CONTAINERS=$(docker-compose ps -q 2>/dev/null | wc -l)
    if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
        echo "⚠️  WARNING: Docker containers are currently running!"
        echo "   For database consistency, you should stop them before backing up."
        echo ""
        read -p "Stop containers now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Stopping containers..."
            docker-compose down
            echo "✓ Containers stopped"
            echo ""
        else
            echo "⚠️  Continuing with backup while containers are running (NOT RECOMMENDED)"
            echo ""
        fi
    fi
fi

echo "Starting MediaWiki backup..."
echo "Base directory: $BASE_DIR_ABS"
echo "Instance directory: $INSTANCE_DIR"
echo "Backup file: $BACKUP_FILE"
echo ""

echo "Scanning instance/ directory for MediaWiki data..."

# Always backup LocalSettings.php
if [ -f "$INSTANCE_DIR/LocalSettings.php" ]; then
    echo "✓ Found LocalSettings.php"
fi

# Backup database directory (MariaDB or SQLite)
if [ -d "$INSTANCE_DIR/db" ]; then
    DB_SIZE=$(du -sh "$INSTANCE_DIR/db" | cut -f1)
    echo "✓ Found db/ directory ($DB_SIZE)"
elif [ -d "$INSTANCE_DIR/data" ]; then
    DB_SIZE=$(du -sh "$INSTANCE_DIR/data" | cut -f1)
    echo "✓ Found data/ directory ($DB_SIZE)"
fi

# Backup images directory
if [ -d "$INSTANCE_DIR/images" ]; then
    IMG_COUNT=$(find "$INSTANCE_DIR/images" -type f 2>/dev/null | wc -l)
    IMG_SIZE=$(du -sh "$INSTANCE_DIR/images" | cut -f1)
    echo "✓ Found images/ directory ($IMG_COUNT files, $IMG_SIZE)"
fi

# Backup custom extensions (if directory exists and not empty)
if [ -d "$INSTANCE_DIR/extensions" ] && [ "$(ls -A "$INSTANCE_DIR/extensions" 2>/dev/null)" ]; then
    echo "✓ Found extensions/ directory"
fi

# Backup custom skins (if directory exists and not empty)
if [ -d "$INSTANCE_DIR/skins" ] && [ "$(ls -A "$INSTANCE_DIR/skins" 2>/dev/null)" ]; then
    echo "✓ Found skins/ directory"
fi

echo ""
echo "Creating backup archive from instance/ directory..."

# Create the tarball from instance directory
# Use -C to change to instance dir, then backup everything with .
cd "$INSTANCE_DIR"
tar -czf "$BASE_DIR_ABS/$BACKUP_FILE" .

echo ""
echo "=========================================="
echo "Backup completed successfully!"
echo "=========================================="
echo "Backup file: $BASE_DIR_ABS/$BACKUP_FILE"
echo "Size: $(du -h "$BASE_DIR_ABS/$BACKUP_FILE" | cut -f1)"
echo ""
echo "To copy this backup to a safe location:"
echo "  cp $BASE_DIR_ABS/$BACKUP_FILE ~/Backups/"
echo ""
