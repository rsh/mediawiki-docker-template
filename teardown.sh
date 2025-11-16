#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "  MediaWiki Teardown Script"
echo "========================================="
echo ""
echo -e "${YELLOW}WARNING: This will:${NC}"
echo "  1. Stop and remove all Docker containers"
echo "  2. Remove Docker networks"
echo "  3. Delete the instance/ directory (database & uploaded files)"
echo ""
echo -e "${RED}This action is IRREVERSIBLE!${NC}"
echo ""
read -r -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${GREEN}Teardown cancelled.${NC}"
    exit 0
fi

# Second confirmation for extra safety
echo ""
echo -e "${RED}FINAL WARNING: All wiki data will be permanently deleted!${NC}"
read -r -p "Type 'DELETE' to confirm: " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "DELETE" ]; then
    echo -e "${GREEN}Teardown cancelled.${NC}"
    exit 0
fi

echo ""
echo "========================================="
echo "  Beginning Teardown Process"
echo "========================================="
echo ""

# Load environment variables if .env exists
if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    echo -e "${BLUE}Loaded configuration from .env${NC}"
else
    echo -e "${YELLOW}Warning: .env file not found, using default container names${NC}"
    WIKI_NAME="my-wiki"
fi

# Stop and remove containers
echo ""
echo -e "${BLUE}Step 1: Stopping Docker containers...${NC}"
if docker-compose ps -q 2>/dev/null | grep -q .; then
    docker-compose down
    echo -e "${GREEN}✓ Containers stopped and removed${NC}"
else
    echo -e "${YELLOW}No running containers found${NC}"
fi

# Remove specific containers by name (in case they exist outside compose)
echo ""
echo -e "${BLUE}Step 2: Removing containers by name...${NC}"
CONTAINERS="${CONTAINER_MEDIAWIKI_NAME:-${WIKI_NAME}} ${CONTAINER_DB_NAME:-${WIKI_NAME}-db}"
for container in $CONTAINERS; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        docker rm -f "$container" 2>/dev/null || true
        echo -e "${GREEN}✓ Removed container: $container${NC}"
    fi
done

# Remove network
echo ""
echo -e "${BLUE}Step 3: Removing Docker network...${NC}"
NETWORK_NAME="${WIKI_NAME}_network"
if docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    docker network rm "$NETWORK_NAME" 2>/dev/null || true
    echo -e "${GREEN}✓ Removed network: $NETWORK_NAME${NC}"
else
    echo -e "${YELLOW}Network not found: $NETWORK_NAME${NC}"
fi

# Remove instance directory
echo ""
echo -e "${BLUE}Step 4: Removing instance directory...${NC}"
INSTANCE_DIR="$SCRIPT_DIR/instance"
if [ -d "$INSTANCE_DIR" ]; then
    # Check if we need sudo to remove files
    if [ -w "$INSTANCE_DIR/db" ] 2>/dev/null && [ -w "$INSTANCE_DIR/images" ] 2>/dev/null; then
        rm -rf "$INSTANCE_DIR"
        echo -e "${GREEN}✓ Removed instance directory${NC}"
    else
        echo -e "${YELLOW}Some files require elevated privileges to remove${NC}"
        sudo rm -rf "$INSTANCE_DIR"
        echo -e "${GREEN}✓ Removed instance directory (with sudo)${NC}"
    fi
else
    echo -e "${YELLOW}Instance directory not found${NC}"
fi

# Optional: Remove .env file
echo ""
read -r -p "Do you want to remove the .env file? (yes/no): " REMOVE_ENV
if [ "$REMOVE_ENV" = "yes" ]; then
    if [ -f "$ENV_FILE" ]; then
        rm "$ENV_FILE"
        echo -e "${GREEN}✓ Removed .env file${NC}"
    fi
else
    echo -e "${YELLOW}Kept .env file${NC}"
fi

echo ""
echo "========================================="
echo -e "${GREEN}  Teardown Complete!${NC}"
echo "========================================="
echo ""
echo "Your wiki has been completely removed."
echo "To start fresh, run: ./setup.sh"
echo ""
