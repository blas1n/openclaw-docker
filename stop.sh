#!/usr/bin/env bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}🛑 Stopping OpenClaw...${NC}"

# Stop and remove sandbox containers inside DinD
# Sandbox containers live inside the DinD daemon, not host Docker
SBX_CONTAINERS=$(DOCKER_HOST=tcp://127.0.0.1:2375 docker ps -aq --filter name=openclaw-sbx 2>/dev/null || true)
if [ -n "$SBX_CONTAINERS" ]; then
    echo -e "${GREEN}🧹 Removing sandbox containers from DinD...${NC}"
    DOCKER_HOST=tcp://127.0.0.1:2375 docker rm -f $SBX_CONTAINERS 2>/dev/null || true
fi

docker-compose down

echo -e "${GREEN}✅ OpenClaw stopped${NC}"
echo ""
echo "To start again: ./start.sh"
echo "To remove all data: docker-compose down -v"