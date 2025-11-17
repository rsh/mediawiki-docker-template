# MediaWiki Docker Template

A template repository for deploying MediaWiki instances using Docker with MariaDB. This setup supports both development and production environments with a clean configuration structure.

## Features

- Docker-based setup with MariaDB
- Environment variable configuration via `.env`
- Secure password generation
- Backup and restore scripts
- Separate dev and production configurations
- Caddy reverse proxy support for production
- Smart startup script that handles first-time setup automatically

## Prerequisites

- Docker and Docker Compose installed
- Git (for cloning)
- Bash shell (Linux, macOS, or WSL on Windows)

## TL;DR - Get Started in 5 Commands

```bash
# 1. Clone and enter directory
git clone <your-repo-url> my-wiki && cd my-wiki

# 2. Setup (creates .env with all configuration)
./setup.sh "My Wiki Name"

# 3. Start (handles first-time setup automatically)
./start.sh

# 4. Complete the MediaWiki wizard in your browser, then:
cp ~/Downloads/LocalSettings.php instance/
./configure-localsettings.sh

# 5. Restart in normal mode
./start.sh
```

Done! Your wiki is running at `http://localhost:8080`

## Quick Start

### 1. Clone the Repository

```bash
# Clone this repository
git clone <your-repo-url> my-wiki
cd my-wiki
```

### 2. Run Setup Script

The setup script will create your `.env` file and generate secure credentials:

```bash
# Option 1: Interactive mode (will prompt for all settings)
./setup.sh

# Option 2: Quick mode with wiki name (can include spaces)
./setup.sh "My Personal Wiki"

# Option 3: Quick mode with multi-word name
./setup.sh "John's Project Wiki"
```

The script will:
- Accept wiki names with spaces (e.g., "My Personal Wiki")
- Automatically sanitize names for containers (e.g., "my-personal-wiki")
- Create database names with underscores (e.g., "my_personal_wiki")
- Prompt for development port and production domain
- Generate a secure random database password
- Create the `.env` file with all settings

**Note:** If `.env` already exists, the script will skip configuration and only generate a password if needed.

### 3. Start MediaWiki

The smart startup script automatically handles first-time setup vs normal operation:

```bash
# For local development
./start.sh

# For production (with Caddy reverse proxy)
./start.sh prod
```

**First Time Setup:** If `LocalSettings.php` doesn't exist, the script starts in setup mode and guides you through installation.

**Normal Operation:** If `LocalSettings.php` exists, the script starts your wiki normally.

### 4. Complete Installation (First Time Only)

When starting for the first time, the script will display:
- The URL to access the installation wizard
- All database credentials needed for setup

1. Visit the URL shown by the script
2. Follow the MediaWiki installation wizard
3. Use the database settings displayed by the script:
   - **Database host:** Shown by script (e.g., `{WIKI_NAME}-db`)
   - **Database name:** From your `.env`
   - **Database username:** From your `.env`
   - **Database password:** From your `.env`
4. Download the generated `LocalSettings.php`
5. Configure LocalSettings.php with the correct URLs:
   ```bash
   # Copy the downloaded file
   cp ~/Downloads/LocalSettings.php instance/

   # Configure server URL automatically
   ./configure-localsettings.sh          # For development
   # OR
   ./configure-localsettings.sh prod     # For production
   ```
6. Run `./start.sh` (or `./start.sh prod`) again - the script will detect the file and start normally

**What does configure-localsettings.sh do?**
- Sets `$wgServer` to the correct URL (localhost:port for dev, or your domain for prod)
- Updates `$wgDBserver` to use the correct container name
- Optionally applies recommended UI theme settings:
  - Vector 2022 skin (modern, responsive design)
  - Short URLs (`/wiki/Page_Title` instead of `/index.php?title=Page_Title`)
  - Lowercase page titles (allows mixed-case page names)
  - Optimized font size for readability



## Maintenance

### Creating Backups

To backup your MediaWiki instance:

```bash
# Stop containers first for database consistency
docker compose down

# Create backup
./backup-mediawiki.sh

# Restart containers
docker compose up -d
```

This creates a timestamped `mediawiki-backup-YYYYMMDD_HHMMSS.tar.gz` file.

**Important:** Store backups in a safe location outside this repository (e.g., `~/Backups/`, external drive, or cloud storage).

### Restoring from Backup

```bash
./restore-backup.sh ~/Backups/mediawiki-backup-YYYYMMDD_HHMMSS.tar.gz

# Start containers
docker compose up -d
```


### Updating MediaWiki

```bash
# Pull the latest images
docker compose pull

# Restart with new images
docker compose up -d
```

### Complete Teardown

To completely remove a wiki instance:

```bash
./teardown.sh
```

**Warning:** This is irreversible! Make sure you have backups before running.

## Troubleshooting

### Database Connection Issues

If you see database errors:
1. Ensure the database container is running: `docker ps`
2. Check database exists: `docker exec -it {CONTAINER_DB_NAME} mysql -u {DB_USER} -p -e "SHOW DATABASES;"`
3. Verify `instance/LocalSettings.php` has correct credentials matching your `.env`
4. Ensure `$wgDBserver` in LocalSettings.php matches `CONTAINER_DB_NAME` from `.env`

### Missing Images

If images don't load:
1. Check `instance/images/` directory has content
2. Verify permissions are correct (set by restore script)
3. Check `$wgUploadPath` in LocalSettings.php

### Port Conflicts

If your dev port is in use:
1. Edit `.env` and change `DEV_PORT` to another port (e.g., `8081`)
2. Restart: `docker compose down && docker compose up -d`
3. Update `$wgServer` in `instance/LocalSettings.php` to match new port

### Database Won't Start

If the database container keeps restarting:
1. Check logs: `docker logs {CONTAINER_DB_NAME}`
2. Ensure `instance/db/` directory has correct permissions (775, group 999)
3. If corrupted, restore from backup

### Permission Issues

If you encounter permission errors:
1. Database directory needs group ownership by UID 999 (mysql)
2. Images directory needs group ownership by UID 33 (www-data)
3. The restore script sets these automatically, or manually run:
   ```bash
   sudo chown -R $(id -u):999 instance/db
   sudo chmod -R 775 instance/db
   sudo chown -R $(id -u):33 instance/images
   sudo find instance/images -type d -exec chmod 775 {} \;
   sudo find instance/images -type f -exec chmod 664 {} \;
   ```

## Production Deployment

When deploying to production with Caddy:

1. **Configure your `.env`** with production domain:
   ```bash
   PROD_DOMAIN=wiki.example.com
   ```

2. **Ensure the `caddy_network` exists**:
   ```bash
   docker network create caddy_network
   ```

3. **Configure Caddy** (Caddyfile) to reverse proxy to the wiki:
   ```
   {PROD_DOMAIN} {
       reverse_proxy {CONTAINER_MEDIAWIKI_NAME}:80
   }
   ```
   Replace variables with actual values from your `.env`.

4. **Update LocalSettings.php** with production URL:
   ```php
   $wgServer = "https://{PROD_DOMAIN}";
   ```

5. **Start the production stack**:
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
   ```


## Quick Reference

### Development (Local)
```bash
# Start containers (use smart startup script)
./start.sh

# Access at: http://localhost:{DEV_PORT}

# Stop containers
docker compose down

# View logs
docker compose logs -f

# View logs for specific service
docker compose logs -f mediawiki
docker compose logs -f database
```

**Advanced:** If you prefer direct docker compose commands:
```bash
# Normal operation (when LocalSettings.php exists)
docker compose up -d

# First-time setup (when LocalSettings.php doesn't exist yet)
docker compose -f docker-compose.yml -f docker-compose.init.yml -f docker-compose.override.yml up -d
```

### Production (with Caddy)
```bash
# Start containers (use smart startup script)
./start.sh prod

# Access at: https://{PROD_DOMAIN} (through Caddy)

# Stop containers
docker compose down

# View logs
docker compose logs -f
```

**Advanced:** If you prefer direct docker compose commands:
```bash
# Normal operation (when LocalSettings.php exists)
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# First-time setup (when LocalSettings.php doesn't exist yet)
docker compose -f docker-compose.yml -f docker-compose.init.yml -f docker-compose.prod.yml up -d
```


# Custom CSS

Go to the page Mediawiki:Common.css

'''
.mw-logo-container {
    color: black;
    font-size: 24px;
}

.mw-first-heading, .mw-page-title-namespace, .mw-page-title-separator, .mw-page-title-main, .mw-headline {
    font-family: sans-serif;
}

.vector-main-menu-dropdown  { display:none; }
'''
