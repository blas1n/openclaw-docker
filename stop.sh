#!/usr/bin/env bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}🛑 Stopping OpenClaw...${NC}"

docker-compose down

echo -e "${GREEN}✅ OpenClaw stopped${NC}"
echo ""
echo "To start again: ./start.sh"
echo "To remove all data: docker-compose down -v"