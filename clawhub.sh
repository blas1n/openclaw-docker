#!/usr/bin/env bash
# ClawHub CLI wrapper for OpenClaw Docker setup
# Installs/manages skills in the container's workspace directory
#
# Usage:
#   ./clawhub.sh install tavily-search
#   ./clawhub.sh search "web search"
#   ./clawhub.sh update
#   ./clawhub.sh list

set -euo pipefail

SKILLS_DIR="./data/workspace/skills"

# Ensure workspace/skills directory exists
mkdir -p "$SKILLS_DIR"

# Run clawhub with workdir pointed to the container's workspace mount
exec npx --yes clawhub@latest \
  --workdir ./data/workspace \
  --dir skills \
  "$@"
