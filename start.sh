#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting OpenClaw with Tailscale Security${NC}"
echo ""

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Error: Docker is not running${NC}"
    echo "Please start Docker (or Colima) first:"
    echo "  colima start"
    exit 1
fi

# Check if .env exists and has Tailscale auth key
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  No .env file found${NC}"
    echo "Creating from template..."
    cp .env.example .env

    echo ""
    echo -e "${YELLOW}📝 IMPORTANT: Edit .env and add your Tailscale auth key${NC}"
    echo ""
    echo "1. Visit: https://login.tailscale.com/admin/settings/keys"
    echo "2. Generate a new auth key with tag:openclaw"
    echo "3. Add it to .env file:"
    echo -e "   ${BLUE}TS_AUTHKEY=tskey-auth-xxx-your-key-here${NC}"
    echo ""
    echo "Press Enter to continue after updating .env, or Ctrl+C to abort..."
    read
else
    # Check if TS_AUTHKEY is set
    if ! grep -q "^TS_AUTHKEY=tskey-auth" .env 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Tailscale auth key not configured in .env${NC}"
        echo ""
        echo "Please update .env with your Tailscale auth key:"
        echo "1. Visit: https://login.tailscale.com/admin/settings/keys"
        echo "2. Generate a new auth key"
        echo "3. Add it to .env:"
        echo -e "   ${BLUE}TS_AUTHKEY=tskey-auth-xxx-your-key-here${NC}"
        echo ""
        exit 1
    fi
fi

# Check if openclaw.json exists
if [ ! -f openclaw.json ]; then
    echo -e "${YELLOW}⚠️  No openclaw.json found${NC}"
    echo "Creating from template..."
    if command -v openssl &> /dev/null; then
        TOKEN=$(openssl rand -hex 32)
        cat openclaw.json.example | sed "s/YOUR_LONG_RANDOM_TOKEN_HERE/$TOKEN/" > openclaw.json
        echo -e "${GREEN}✅ Generated openclaw.json with secure token${NC}"
    else
        cp openclaw.json.example openclaw.json
        echo -e "${YELLOW}⚠️  Please edit openclaw.json and set gateway.auth.token${NC}"
    fi
    echo ""
fi

# Check if host Tailscale is running
if command -v tailscale &> /dev/null; then
    if tailscale status &> /dev/null; then
        HOST_TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✅ Host Tailscale is running${NC}"
        echo -e "   Host IP: ${GREEN}$HOST_TAILSCALE_IP${NC}"
        echo ""
    fi
else
    echo -e "${BLUE}ℹ️  Tailscale CLI not found on host${NC}"
    echo "   The Docker container will still join your Tailscale network."
    echo ""
fi

# Create logs directory
mkdir -p logs

# Pull latest images
echo -e "${GREEN}📥 Pulling latest Docker images...${NC}"
docker-compose pull

echo ""

# Start containers
echo -e "${GREEN}🐳 Starting Tailscale sidecar and OpenClaw...${NC}"
docker-compose up -d

# Wait for Tailscale to connect
echo -e "${GREEN}⏳ Waiting for Tailscale to connect (may take 10-30 seconds)...${NC}"
sleep 10

# Try to get Tailscale IP from container
MAX_RETRIES=6
RETRY_COUNT=0
CONTAINER_TAILSCALE_IP=""

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    CONTAINER_TAILSCALE_IP=$(docker exec openclaw-tailscale tailscale ip -4 2>/dev/null || echo "")
    if [ -n "$CONTAINER_TAILSCALE_IP" ] && [ "$CONTAINER_TAILSCALE_IP" != "" ]; then
        break
    fi
    echo -e "${YELLOW}   Waiting for Tailscale to establish connection... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)${NC}"
    sleep 5
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

echo ""

# Enable Tailscale HTTPS Serve
echo -e "${GREEN}🔐 Enabling Tailscale HTTPS...${NC}"

# Get Tailscale IP for proxy target
if [ -n "$CONTAINER_TAILSCALE_IP" ] && [ "$CONTAINER_TAILSCALE_IP" != "" ]; then
    PROXY_TARGET="http://${CONTAINER_TAILSCALE_IP}:18789"
else
    # Fallback to getting IP again
    CONTAINER_TAILSCALE_IP=$(docker exec openclaw-tailscale tailscale ip -4 2>/dev/null || echo "")
    if [ -n "$CONTAINER_TAILSCALE_IP" ]; then
        PROXY_TARGET="http://${CONTAINER_TAILSCALE_IP}:18789"
    else
        echo -e "${YELLOW}   ⚠️  Cannot determine Tailscale IP, skipping HTTPS setup${NC}"
        PROXY_TARGET=""
    fi
fi

if [ -n "$PROXY_TARGET" ]; then
    if docker exec openclaw-tailscale tailscale serve status 2>&1 | grep -q "No serve config"; then
        echo "   Setting up HTTPS proxy to $PROXY_TARGET..."
        docker exec openclaw-tailscale tailscale serve --https 443 --bg "$PROXY_TARGET" 2>&1 | grep -v "Serve is not enabled" || true
        sleep 2
    fi
fi

TAILSCALE_HOSTNAME=$(docker exec openclaw-tailscale tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | cut -d'"' -f4 | sed 's/\.$//' || echo "")

echo ""

# Check if containers are running
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ OpenClaw is running!${NC}"
    echo ""

    # Display Tailscale information
    if [ -n "$CONTAINER_TAILSCALE_IP" ] && [ "$CONTAINER_TAILSCALE_IP" != "" ]; then
        echo -e "${GREEN}🔗 Access OpenClaw from any Tailscale device:${NC}"

        if [ -n "$TAILSCALE_HOSTNAME" ]; then
            echo -e "${GREEN}   HTTPS (Recommended):${NC}"
            echo -e "   ${BLUE}https://$TAILSCALE_HOSTNAME/${NC}"
            echo ""
            echo -e "${GREEN}   HTTP (Alternative):${NC}"
        fi
        echo -e "   ${BLUE}http://$CONTAINER_TAILSCALE_IP:18789${NC}"
        echo ""
        echo -e "   Tailscale device name: ${GREEN}openclaw${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not retrieve Tailscale IP${NC}"
        echo ""
        echo "Check Tailscale status:"
        echo "  docker exec openclaw-tailscale tailscale status"
        echo ""
        echo "Get Tailscale IP manually:"
        echo "  docker exec openclaw-tailscale tailscale ip -4"
        echo ""
        echo "Or check your Tailscale admin console:"
        echo "  https://login.tailscale.com/admin/machines"
        echo ""
    fi

    # Display authentication token
    if [ -f openclaw.json ]; then
        TOKEN=$(grep -o '"token": "[^"]*"' openclaw.json | head -1 | cut -d'"' -f4)
        if [ -n "$TOKEN" ] && [ "$TOKEN" != "YOUR_LONG_RANDOM_TOKEN_HERE" ]; then
            echo -e "${GREEN}🔑 Authentication Token:${NC}"
            echo -e "   ${BLUE}$TOKEN${NC}"
            echo "   (Save this for client configuration)"
        fi
    fi

    echo ""
    echo -e "${GREEN}📊 Useful commands:${NC}"
    echo "  View logs:         docker-compose logs -f"
    echo "  Tailscale status:  docker exec openclaw-tailscale tailscale status"
    echo "  Tailscale IP:      docker exec openclaw-tailscale tailscale ip -4"
    echo "  Stop:              docker-compose down"
    echo "  Restart:           docker-compose restart"
else
    echo -e "${RED}❌ Failed to start OpenClaw${NC}"
    echo ""
    echo "Check logs:"
    echo "  docker-compose logs tailscale"
    echo "  docker-compose logs openclaw"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify TS_AUTHKEY in .env is valid"
    echo "  2. Check Tailscale admin console for device approval"
    echo "  3. Run: docker-compose logs"
    exit 1
fi
