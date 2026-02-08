#!/usr/bin/env bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="openclaw-backup-${TIMESTAMP}.tar.gz"

echo -e "${GREEN}💾 Backing up OpenClaw configuration...${NC}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create temporary directory for backup
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Copy configuration files
echo "Copying configuration files..."
cp .env "$TMP_DIR/" 2>/dev/null || echo -e "${YELLOW}⚠️  No .env file found${NC}"
cp docker-compose.yml "$TMP_DIR/"

# Backup Docker volume
if docker volume inspect openclaw-docker_openclaw-data &> /dev/null; then
    echo "Backing up Docker volume..."
    docker run --rm \
        -v openclaw-docker_openclaw-data:/data \
        -v "$TMP_DIR":/backup \
        alpine:latest \
        tar czf /backup/volume-data.tar.gz -C /data .
else
    echo -e "${YELLOW}⚠️  No Docker volume found${NC}"
fi

# Create final backup archive
echo "Creating backup archive..."
tar czf "${BACKUP_DIR}/${BACKUP_FILE}" -C "$TMP_DIR" .

echo ""
echo -e "${GREEN}✅ Backup completed!${NC}"
echo "Backup saved to: ${BACKUP_DIR}/${BACKUP_FILE}"
echo ""
echo "To restore:"
echo "  tar xzf ${BACKUP_DIR}/${BACKUP_FILE} -C /path/to/restore"