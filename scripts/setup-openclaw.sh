#!/usr/bin/env bash
# setup-openclaw.sh — Install and configure OpenClaw AI gateway in GitHub Codespaces
set -euo pipefail

# ── colours ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
section() { echo -e "\n${GREEN}══════════════════════════════════════${NC}"; echo -e "${GREEN} $*${NC}"; echo -e "${GREEN}══════════════════════════════════════${NC}"; }

# ── helpers ────────────────────────────────────────────────────────────────────
need_cmd() { command -v "$1" &>/dev/null || error "Required command not found: $1"; }

# ── step 1 : install ───────────────────────────────────────────────────────────
install_openclaw() {
  section "Step 1 — Installing OpenClaw"

  if command -v openclaw &>/dev/null; then
    info "OpenClaw already installed: $(openclaw --version 2>/dev/null || echo 'version unknown')"
    return
  fi

  need_cmd curl
  info "Downloading and running OpenClaw installer..."
  curl -fsSL https://openclaw.ai/install.sh | bash

  # Make sure the binary is on PATH for the rest of this script
  export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

  command -v openclaw &>/dev/null || error "Installation finished but 'openclaw' not found on PATH. Check installer output."
  info "OpenClaw installed successfully."
}

# ── step 2 : start gateway ────────────────────────────────────────────────────
start_gateway() {
  local port="${OPENCLAW_PORT:-18789}"
  section "Step 2 — Starting OpenClaw Gateway (port $port)"

  # Check if already running
  if openclaw gateway status 2>/dev/null | grep -qi "running"; then
    info "Gateway is already running."
    return
  fi

  info "Starting gateway in background on port $port..."
  nohup openclaw gateway --port "$port" > /tmp/openclaw-gateway.log 2>&1 &
  GATEWAY_PID=$!
  echo "$GATEWAY_PID" > /tmp/openclaw-gateway.pid

  # Wait up to 15 s for the gateway to come up
  local waited=0
  until openclaw gateway status 2>/dev/null | grep -qi "running" || [ $waited -ge 15 ]; do
    sleep 1; (( waited++ )) || true
  done

  if openclaw gateway status 2>/dev/null | grep -qi "running"; then
    info "Gateway is up (PID $GATEWAY_PID, log: /tmp/openclaw-gateway.log)."
  else
    warn "Gateway may not have started yet — check /tmp/openclaw-gateway.log"
  fi
}

# ── step 3 : check gateway status ─────────────────────────────────────────────
check_status() {
  section "Step 3 — Gateway Status"
  openclaw gateway status || warn "Could not retrieve gateway status."
}

# ── step 4 : whatsapp login ───────────────────────────────────────────────────
login_whatsapp() {
  section "Step 4 — WhatsApp Login"

  info "Checking WhatsApp connectivity..."
  if curl -IsS --max-time 10 https://web.whatsapp.com/ | head -1 | grep -q "200\|301\|302"; then
    info "web.whatsapp.com is reachable."
  else
    warn "web.whatsapp.com did not return a success response — check your network."
  fi

  echo ""
  info "Launching WhatsApp channel login (follow the on-screen instructions)..."
  openclaw channels login --channel whatsapp
}

# ── step 5 : configure model ──────────────────────────────────────────────────
configure_model() {
  section "Step 5 — Model Configuration"
  info "Opening interactive model selector..."
  openclaw configure --section model
}

# ── usage / argument parsing ──────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --install          Install OpenClaw only
  --start            Start the gateway (default port: 18789)
  --status           Show gateway status
  --login-whatsapp   Log in via WhatsApp
  --configure-model  Select AI model interactively
  --all              Run all steps in sequence (default)
  --port PORT        Gateway port (default: 18789)
  -h, --help         Show this help

Environment:
  OPENCLAW_PORT      Override gateway port (default: 18789)

Examples:
  # Run everything (install → start → status → whatsapp → model)
  bash setup-openclaw.sh --all

  # Install only
  bash setup-openclaw.sh --install

  # Start gateway on custom port
  bash setup-openclaw.sh --start --port 9000

  # Just configure the model
  bash setup-openclaw.sh --configure-model
EOF
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  local do_install=false do_start=false do_status=false
  local do_whatsapp=false do_model=false do_all=false

  if [ $# -eq 0 ]; then do_all=true; fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --install)          do_install=true ;;
      --start)            do_start=true ;;
      --status)           do_status=true ;;
      --login-whatsapp)   do_whatsapp=true ;;
      --configure-model)  do_model=true ;;
      --all)              do_all=true ;;
      --port)             shift; export OPENCLAW_PORT="$1" ;;
      -h|--help)          usage; exit 0 ;;
      *) error "Unknown option: $1. Run with --help for usage." ;;
    esac
    shift
  done

  if $do_all; then
    do_install=true; do_start=true; do_status=true
    do_whatsapp=true; do_model=true
  fi

  $do_install       && install_openclaw
  $do_start         && start_gateway
  $do_status        && check_status
  $do_whatsapp      && login_whatsapp
  $do_model         && configure_model

  section "Done"
  info "OpenClaw setup complete."
  info "Gateway log: /tmp/openclaw-gateway.log"
  info "Run 'openclaw --help' to explore available commands."
}

main "$@"
