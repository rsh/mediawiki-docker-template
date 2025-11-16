#!/bin/bash
# MediaWiki Clean Script
# Removes all data files from the instance/ directory
#
# Usage:
#   ./clean.sh [base_directory]
#
# If no directory is provided, uses current directory
# Cleans the instance/ subdirectory within the base directory
#
# This script is useful for:
# - Preparing for a fresh backup restore
# - Cleaning up before switching between backups
# - Removing all local data

set -e

BASE_DIR="${1:-.}"

cd "$BASE_DIR"
BASE_DIR_ABS=$(pwd)
INSTANCE_DIR="$BASE_DIR_ABS/instance"

echo "=========================================="
echo "MediaWiki Clean Script"
echo "=========================================="
echo "Base directory: $BASE_DIR_ABS"
echo "Instance directory: $INSTANCE_DIR"
echo ""

# Check if instance directory exists
if [ ! -d "$INSTANCE_DIR" ]; then
    echo "✓ No instance/ directory found. Nothing to clean."
    exit 0
fi

# Step 1: Stop running containers
if [ -f "docker-compose.yml" ] && command -v docker-compose >/dev/null 2>&1; then
    RUNNING_CONTAINERS=$(docker-compose ps -q 2>/dev/null | wc -l)
    if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
        echo "⚠️  WARNING: Docker containers are currently running!"
        echo ""
        read -p "Stop containers before cleaning? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Stopping containers..."
            docker-compose down
            echo "✓ Containers stopped"
            echo ""
        else
            echo "❌ Cannot clean while containers are running. Exiting."
            exit 1
        fi
    fi
fi

# Step 2: Check for existing data in instance/
EXISTING_DATA=()
if [ -f "$INSTANCE_DIR/LocalSettings.php" ]; then
    EXISTING_DATA+=("instance/LocalSettings.php")
fi
if [ -d "$INSTANCE_DIR/db" ]; then
    EXISTING_DATA+=("instance/db/")
fi
if [ -d "$INSTANCE_DIR/images" ]; then
    EXISTING_DATA+=("instance/images/")
fi

if [ ${#EXISTING_DATA[@]} -eq 0 ]; then
    echo "✓ No data files found in instance/. Directory is already clean."
    exit 0
fi

# Step 3: Confirm deletion
echo "⚠️  WARNING: The following data will be PERMANENTLY DELETED:"
for item in "${EXISTING_DATA[@]}"; do
    FULL_PATH="$INSTANCE_DIR/${item#instance/}"
    if [ -d "$FULL_PATH" ]; then
        SIZE=$(du -sh "$FULL_PATH" 2>/dev/null | cut -f1 || echo "unknown")
        echo "   - $item ($SIZE)"
    else
        echo "   - $item"
    fi
done
echo ""
echo "❗ THIS ACTION CANNOT BE UNDONE!"
echo ""
read -p "Continue with deletion? (yes/NO): " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Clean cancelled."
    exit 0
fi

# Step 4: Remove data files from instance/
echo "Removing data files from instance/..."

# Remove LocalSettings.php
if [ -f "$INSTANCE_DIR/LocalSettings.php" ]; then
    rm "$INSTANCE_DIR/LocalSettings.php"
    echo "✓ Removed instance/LocalSettings.php"
fi

# Remove images directory
if [ -d "$INSTANCE_DIR/images" ]; then
    rm -rf "$INSTANCE_DIR/images"
    echo "✓ Removed instance/images/"
fi

# Remove database directory (may need sudo)
if [ -d "$INSTANCE_DIR/db" ]; then
    if rm -rf "$INSTANCE_DIR/db" 2>/dev/null; then
        echo "✓ Removed instance/db/"
    else
        echo "⚠️  Need elevated permissions to remove instance/db/"
        sudo rm -rf "$INSTANCE_DIR/db"
        echo "✓ Removed instance/db/ (with sudo)"
    fi
fi

# Remove instance directory if empty
if [ -d "$INSTANCE_DIR" ] && [ -z "$(ls -A "$INSTANCE_DIR")" ]; then
    rmdir "$INSTANCE_DIR"
    echo "✓ Removed empty instance/ directory"
fi

echo ""
echo "=========================================="
echo "Clean completed successfully!"
echo "=========================================="
echo "All MediaWiki data has been removed from instance/."
echo ""
echo "Next steps:"
echo "- To restore a backup: ./restore-backup.sh <backup-file.tar.gz>"
echo "- To start fresh: Set up MediaWiki from scratch"
echo ""
