#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
LOCAL_SETTINGS="$SCRIPT_DIR/instance/LocalSettings.php"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please run ./setup.sh first."
    exit 1
fi

# Source the .env file
# shellcheck source=/dev/null
source "$ENV_FILE"

# Check if LocalSettings.php exists
if [ ! -f "$LOCAL_SETTINGS" ]; then
    echo -e "${RED}Error: LocalSettings.php not found!${NC}"
    echo "Expected location: $LOCAL_SETTINGS"
    echo ""
    echo "Please download LocalSettings.php from the MediaWiki installer and place it at:"
    echo "  ${YELLOW}${LOCAL_SETTINGS}${NC}"
    exit 1
fi

echo "========================================="
echo "  Configure LocalSettings.php"
echo "========================================="
echo ""

# Determine mode
MODE="${1:-dev}"

if [ "$MODE" = "prod" ]; then
    NEW_SERVER="https://${PROD_DOMAIN}"
    echo -e "${BLUE}Configuring for PRODUCTION mode${NC}"
    echo "Setting \$wgServer to: ${YELLOW}${NEW_SERVER}${NC}"
else
    NEW_SERVER="http://localhost:${DEV_PORT}"
    echo -e "${BLUE}Configuring for DEVELOPMENT mode${NC}"
    echo "Setting \$wgServer to: ${YELLOW}${NEW_SERVER}${NC}"
fi

echo ""

# Check if $wgServer already exists
if grep -q '^\$wgServer' "$LOCAL_SETTINGS"; then
    # Update existing $wgServer
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|^\$wgServer.*|\$wgServer = \"$NEW_SERVER\";|" "$LOCAL_SETTINGS"
    else
        # Linux
        sed -i "s|^\$wgServer.*|\$wgServer = \"$NEW_SERVER\";|" "$LOCAL_SETTINGS"
    fi
    echo -e "${GREEN}✓ Updated \$wgServer in LocalSettings.php${NC}"
else
    # Check for conditional $wgServer (like in stoddard-wiki)
    if grep -q 'wgServer.*=.*"http' "$LOCAL_SETTINGS"; then
        echo -e "${YELLOW}Note: Found conditional \$wgServer configuration${NC}"
        echo "You may want to manually review: $LOCAL_SETTINGS"
        echo ""
        echo "For simple configuration, replace your conditional \$wgServer with:"
        if [ "$MODE" = "prod" ]; then
            echo "  \$wgServer = \"https://${PROD_DOMAIN}\";"
        else
            echo "  \$wgServer = \"http://localhost:${DEV_PORT}\";"
        fi
    else
        # Add $wgServer after $wgScriptPath
        if grep -q '^\$wgScriptPath' "$LOCAL_SETTINGS"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "/^\$wgScriptPath/a\\
\\
## The protocol and server name to use in fully-qualified URLs\\
\$wgServer = \"$NEW_SERVER\";\\
" "$LOCAL_SETTINGS"
            else
                sed -i "/^\$wgScriptPath/a\\
\\
## The protocol and server name to use in fully-qualified URLs\\
\$wgServer = \"$NEW_SERVER\";" "$LOCAL_SETTINGS"
            fi
            echo -e "${GREEN}✓ Added \$wgServer to LocalSettings.php${NC}"
        else
            echo -e "${YELLOW}Warning: Could not automatically add \$wgServer${NC}"
            echo "Please manually add this line to LocalSettings.php:"
            echo "  \$wgServer = \"$NEW_SERVER\";"
        fi
    fi
fi

# Update $wgDBserver to use container name
CONTAINER_DB_NAME="${WIKI_NAME}-db"
if grep -q '^\$wgDBserver' "$LOCAL_SETTINGS"; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^\$wgDBserver.*|\$wgDBserver = \"$CONTAINER_DB_NAME\";|" "$LOCAL_SETTINGS"
    else
        sed -i "s|^\$wgDBserver.*|\$wgDBserver = \"$CONTAINER_DB_NAME\";|" "$LOCAL_SETTINGS"
    fi
    echo -e "${GREEN}✓ Updated \$wgDBserver to use container name${NC}"
fi

echo ""
echo -e "${GREEN}Configuration complete!${NC}"
echo ""
