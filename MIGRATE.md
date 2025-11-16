# Migrating to instance/ Directory Structure

This guide helps you migrate from the old flat structure to the new `instance/` directory structure.

## What Changed?

### Old Structure (Flat)
```
rayhan-wiki/
├── LocalSettings.php      # At root level
├── db/                    # At root level
├── images/                # At root level
├── docker-compose.yml
└── ...
```

### New Structure (Organized)
```
rayhan-wiki/
├── instance/              # All data contained here
│   ├── LocalSettings.php
│   ├── db/
│   └── images/
├── docker-compose.yml
└── ...
```

## Migration Steps

### Option 1: Manual Migration (If containers are already running)

```bash
# 1. Stop containers
docker-compose down

# 2. Create instance directory
mkdir -p instance

# 3. Move data files into instance/
mv LocalSettings.php instance/
mv db instance/
mv images instance/

# 4. Start containers with new structure
docker-compose up -d
```

### Option 2: Clean Migration (Recommended - uses backup/restore)

```bash
# 1. Create a backup of current data (before changes)
#    This backs up from old structure if you haven't updated scripts yet
./backup-mediawiki.sh

# This will create: mediawiki-backup-YYYYMMDD_HHMMSS.tar.gz

# 2. Stop containers
docker-compose down

# 3. Remove old data files (they're safely in the backup)
sudo rm -rf db/
rm -rf images/ LocalSettings.php

# 4. Restore backup (will automatically go into instance/)
./restore-backup.sh mediawiki-backup-YYYYMMDD_HHMMSS.tar.gz

# 5. Start containers
docker-compose up -d
```

### Option 3: If You Have No Data Yet

Just pull the latest changes and start fresh. The `instance/` directory will be created automatically when you restore a backup.

## Verification

After migration, verify your structure:

```bash
# Check that instance/ exists and contains your data
ls -la instance/

# Should show:
# instance/LocalSettings.php
# instance/db/
# instance/images/
```

## Troubleshooting

### "No such file or directory" errors

If you see errors about missing LocalSettings.php or db/images directories:

1. Make sure files are in `instance/` subdirectory
2. Check docker-compose.yml volume mounts point to `./instance/`

### Permission issues with db/

If you can't move the db/ directory:

```bash
# Use sudo to move database files
sudo mv db instance/

# Fix ownership (optional, Docker will handle it)
sudo chown -R $USER:$USER instance/db
```

## Rollback (If Needed)

If something goes wrong, you can rollback:

```bash
# Stop containers
docker-compose down

# Move files back out
mv instance/LocalSettings.php .
mv instance/db .
mv instance/images .
rmdir instance

# Revert docker-compose.yml changes (if you pulled new version)
git checkout docker-compose.yml

# Start containers
docker-compose up -d
```

## After Migration

Once migrated successfully:

- Future backups will automatically backup from `instance/`
- Future restores will automatically restore to `instance/`
- The repo root stays clean with only configuration files
- All data is contained in one gitignored directory
