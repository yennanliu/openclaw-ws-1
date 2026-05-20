#!/usr/bin/env bash
# postCreate.sh — runs automatically when a GitHub Codespace is created
set -euo pipefail

echo "==> Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  curl \
  ca-certificates \
  jq

echo "==> Making scripts executable..."
chmod +x scripts/setup-openclaw.sh

echo "==> Installing OpenClaw AI gateway..."
bash scripts/setup-openclaw.sh --install

echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│  OpenClaw is installed. Next steps:                 │"
echo "│                                                     │"
echo "│  1. Start the gateway (port 18789, forwarded):      │"
echo "│     bash scripts/setup-openclaw.sh --start          │"
echo "│                                                     │"
echo "│  2. Log in with WhatsApp:                           │"
echo "│     bash scripts/setup-openclaw.sh --login-whatsapp │"
echo "│                                                     │"
echo "│  3. Choose your AI model:                           │"
echo "│     bash scripts/setup-openclaw.sh --configure-model│"
echo "│                                                     │"
echo "│  Or run everything at once:                         │"
echo "│     bash scripts/setup-openclaw.sh --all            │"
echo "└─────────────────────────────────────────────────────┘"
