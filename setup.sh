#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "  MediaWiki Template Setup"
echo "========================================="
echo ""

# Function to sanitize wiki name for container/database names (no spaces, lowercase, hyphens)
sanitize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g'
}

# Function to create database name (underscores instead of hyphens)
create_db_name() {
    echo "$1" | tr '-' '_'
}

# Check if .env already exists
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}.env file already exists!${NC}"
    echo ""
    # Source and show existing config
    # shellcheck source=/dev/null
    source "$ENV_FILE"

    # Still generate password if needed
    if [ "$DB_PASSWORD" = "CHANGE_ME_INSECURE_DEFAULT" ]; then
        echo "Generating secure random password..."
        NEW_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/DB_PASSWORD=CHANGE_ME_INSECURE_DEFAULT/DB_PASSWORD=$NEW_PASSWORD/" "$ENV_FILE"
        else
            sed -i "s/DB_PASSWORD=CHANGE_ME_INSECURE_DEFAULT/DB_PASSWORD=$NEW_PASSWORD/" "$ENV_FILE"
        fi
        echo -e "${GREEN}✓ Generated new database password${NC}"
        echo ""
    fi

    echo "========================================="
    echo "  Configuration Summary"
    echo "========================================="
    echo "Wiki Name: ${WIKI_NAME}"
    echo "Display Name: ${WIKI_DISPLAY_NAME}"
    echo "Database: ${DB_NAME}"
    echo "Database User: ${DB_USER}"
    echo "Dev Port: ${DEV_PORT}"
    echo "Production Domain: ${PROD_DOMAIN}"
    echo ""
    echo "Setup complete! Your wiki is ready to launch."
    echo "Run: ${GREEN}./start.sh${NC} to start your wiki"
    echo ""
    exit 0
fi

# .env doesn't exist - create it
echo "Creating new wiki configuration..."
echo ""

# Get wiki display name from argument or prompt
if [ -n "$1" ]; then
    WIKI_DISPLAY_NAME="$1"
    echo -e "${BLUE}Wiki name: ${YELLOW}${WIKI_DISPLAY_NAME}${NC}"
    echo ""
else
    # Interactive mode - prompt for wiki name
    read -r -p "Enter your wiki display name (can include spaces): " WIKI_DISPLAY_NAME

    if [ -z "$WIKI_DISPLAY_NAME" ]; then
        echo -e "${RED}Error: Wiki name cannot be empty${NC}"
        exit 1
    fi
    echo ""
fi

# Generate sanitized names
WIKI_NAME=$(sanitize_name "$WIKI_DISPLAY_NAME")
DB_NAME=$(create_db_name "$WIKI_NAME")

echo "Generated configuration:"
echo "  Display Name: ${YELLOW}${WIKI_DISPLAY_NAME}${NC}"
echo "  Container Name: ${YELLOW}${WIKI_NAME}${NC}"
echo "  Database Name: ${YELLOW}${DB_NAME}${NC}"
echo ""

# Prompt for optional settings
read -r -p "Development port [8080]: " DEV_PORT
DEV_PORT=${DEV_PORT:-8080}

read -r -p "Production domain [wiki.example.com]: " PROD_DOMAIN
PROD_DOMAIN=${PROD_DOMAIN:-wiki.example.com}

# Generate secure password
echo ""
echo "Generating secure random password..."
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Create .env file from template
if [ ! -f "$ENV_EXAMPLE" ]; then
    echo -e "${RED}Error: .env.example not found!${NC}"
    exit 1
fi

# Copy and update .env file
cp "$ENV_EXAMPLE" "$ENV_FILE"

# Use appropriate sed syntax for macOS vs Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/WIKI_NAME=.*/WIKI_NAME=${WIKI_NAME}/" "$ENV_FILE"
    sed -i '' "s/WIKI_DISPLAY_NAME=.*/WIKI_DISPLAY_NAME=\"${WIKI_DISPLAY_NAME}\"/" "$ENV_FILE"
    sed -i '' "s/DB_NAME=.*/DB_NAME=${DB_NAME}/" "$ENV_FILE"
    sed -i '' "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" "$ENV_FILE"
    sed -i '' "s/DEV_PORT=.*/DEV_PORT=${DEV_PORT}/" "$ENV_FILE"
    sed -i '' "s/PROD_DOMAIN=.*/PROD_DOMAIN=${PROD_DOMAIN}/" "$ENV_FILE"
else
    # Linux
    sed -i "s/WIKI_NAME=.*/WIKI_NAME=${WIKI_NAME}/" "$ENV_FILE"
    sed -i "s/WIKI_DISPLAY_NAME=.*/WIKI_DISPLAY_NAME=\"${WIKI_DISPLAY_NAME}\"/" "$ENV_FILE"
    sed -i "s/DB_NAME=.*/DB_NAME=${DB_NAME}/" "$ENV_FILE"
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" "$ENV_FILE"
    sed -i "s/DEV_PORT=.*/DEV_PORT=${DEV_PORT}/" "$ENV_FILE"
    sed -i "s/PROD_DOMAIN=.*/PROD_DOMAIN=${PROD_DOMAIN}/" "$ENV_FILE"
fi

echo -e "${GREEN}✓ Created .env file with secure configuration${NC}"
echo -e "${YELLOW}IMPORTANT: Database password is: ${DB_PASSWORD}${NC}"
echo -e "${YELLOW}           Save this in a secure location!${NC}"
echo ""
echo "========================================="
echo "  Configuration Summary"
echo "========================================="
echo "Wiki Name: ${WIKI_NAME}"
echo "Display Name: ${WIKI_DISPLAY_NAME}"
echo "Database: ${DB_NAME}"
echo "Database User: wikiuser"
echo "Dev Port: ${DEV_PORT}"
echo "Production Domain: ${PROD_DOMAIN}"
echo ""
echo "Setup complete! Your wiki is ready to launch."
echo "Run: ${GREEN}./start.sh${NC} to start your wiki"
echo ""
