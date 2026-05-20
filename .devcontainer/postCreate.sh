#!/usr/bin/env bash
# postCreate.sh — runs automatically when a GitHub Codespace is created.
# Intentionally lightweight: only installs system packages and wires up
# scripts. The openclaw install is left to the user to avoid a silent
# hang if openclaw.ai is slow or unreachable during container creation.
set -euo pipefail

echo "==> Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  curl \
  ca-certificates \
  jq

echo "==> Making scripts executable..."
chmod +x scripts/setup-openclaw.sh
chmod +x scripts/test-setup-openclaw.sh

echo ""
echo "┌──────────────────────────────────────────────────────────┐"
echo "│  Codespace is ready. Open a terminal and run:            │"
echo "│                                                          │"
echo "│  # Step 1 — install OpenClaw                            │"
echo "│  bash scripts/setup-openclaw.sh --install               │"
echo "│                                                          │"
echo "│  # Step 2 — start gateway (port 18789, auto-forwarded)  │"
echo "│  bash scripts/setup-openclaw.sh --start                 │"
echo "│                                                          │"
echo "│  # Step 3 — WhatsApp login (interactive)                │"
echo "│  bash scripts/setup-openclaw.sh --login-whatsapp        │"
echo "│                                                          │"
echo "│  # Step 4 — pick AI model (interactive)                 │"
echo "│  bash scripts/setup-openclaw.sh --configure-model       │"
echo "│                                                          │"
echo "│  Or do everything at once:                               │"
echo "│  bash scripts/setup-openclaw.sh --all                   │"
echo "└──────────────────────────────────────────────────────────┘"
