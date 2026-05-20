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
    persist_token
    return
  fi

  need_cmd curl
  info "Downloading and running OpenClaw installer..."
  curl -fsSL --connect-timeout 15 --max-time 120 https://openclaw.ai/install.sh | bash

  # Make sure the binary is on PATH for the rest of this script
  export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

  command -v openclaw &>/dev/null || error "Installation finished but 'openclaw' not found on PATH. Check installer output."
  info "OpenClaw installed successfully."

  # Persist token to shell profile so it survives new terminal sessions
  persist_token
}

# ── token helpers ─────────────────────────────────────────────────────────────

# Read the gateway token from env var or openclaw config
get_token() {
  # 1. Explicit env var wins
  if [ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
    echo "$OPENCLAW_GATEWAY_TOKEN"
    return
  fi
  # 2. Ask openclaw itself
  local tok
  tok=$(openclaw gateway token 2>/dev/null || true)
  if [ -n "$tok" ]; then
    echo "$tok"
    return
  fi
  # 3. Common config file locations
  for cfg in \
      "$HOME/.openclaw/config.yaml" \
      "$HOME/.config/openclaw/config.yaml" \
      "$HOME/.openclaw.yaml"; do
    if [ -f "$cfg" ]; then
      tok=$(grep -E "^\s*(token|auth\.token)\s*:" "$cfg" 2>/dev/null \
            | head -1 | sed 's/.*:\s*//' | tr -d '"'"'" || true)
      if [ -n "$tok" ]; then echo "$tok"; return; fi
    fi
  done
  echo ""
}

# Build the browser-ready URL with the token fragment appended
build_auth_url() {
  local port="${OPENCLAW_PORT:-18789}"
  local token
  token=$(get_token)

  local base_url
  # Detect GitHub Codespaces environment
  if [ -n "${CODESPACE_NAME:-}" ] && [ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]; then
    base_url="https://${CODESPACE_NAME}-${port}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
  else
    base_url="http://localhost:${port}"
  fi

  if [ -n "$token" ]; then
    echo "${base_url}/#token=${token}"
  else
    echo "$base_url"
  fi
}

# Write OPENCLAW_GATEWAY_TOKEN to the user's shell profile so every new
# terminal is already authenticated without any manual copy-paste.
persist_token() {
  local token
  token=$(get_token)
  [ -n "$token" ] || return 0

  # Export into the current session immediately
  export OPENCLAW_GATEWAY_TOKEN="$token"

  # Write to whichever shell profile exists (prefer zshrc in Codespaces)
  local profile=""
  for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    if [ -f "$f" ]; then profile="$f"; break; fi
  done
  [ -n "$profile" ] || profile="$HOME/.bashrc"

  # Avoid duplicate entries
  if ! grep -q "OPENCLAW_GATEWAY_TOKEN" "$profile" 2>/dev/null; then
    echo "" >> "$profile"
    echo "# OpenClaw gateway token (added by setup-openclaw.sh)" >> "$profile"
    echo "export OPENCLAW_GATEWAY_TOKEN=\"${token}\"" >> "$profile"
    info "Token persisted to $profile — all future terminals will be auto-authenticated."
  else
    # Update in place in case the token changed
    sed -i "s|^export OPENCLAW_GATEWAY_TOKEN=.*|export OPENCLAW_GATEWAY_TOKEN=\"${token}\"|" "$profile"
    info "Token updated in $profile."
  fi
}

# Print (and optionally open) the authenticated UI URL
open_ui() {
  section "OpenClaw UI — Auth URL"

  local token
  token=$(get_token)
  if [ -z "$token" ]; then
    warn "Could not retrieve gateway token."
    warn "Run: openclaw gateway token   and set OPENCLAW_GATEWAY_TOKEN in your shell."
    return 1
  fi

  local url
  url=$(build_auth_url)

  info "Open this URL in your browser (token is embedded — no login prompt):"
  echo ""
  echo "  $url"
  echo ""

  # Copy to clipboard if a tool is available
  if command -v xclip &>/dev/null; then
    echo "$url" | xclip -selection clipboard && info "URL copied to clipboard."
  elif command -v pbcopy &>/dev/null; then
    echo "$url" | pbcopy && info "URL copied to clipboard."
  fi

  # Try to auto-open in browser (no-op if no display)
  if command -v xdg-open &>/dev/null; then
    xdg-open "$url" 2>/dev/null || true
  fi
}

# ── codespaces origin helper ──────────────────────────────────────────────────
# Returns the https:// origin of this codespace (empty if not in Codespaces).
codespace_origin() {
  if [ -n "${CODESPACE_NAME:-}" ] && [ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]; then
    local port="${OPENCLAW_PORT:-18789}"
    echo "https://${CODESPACE_NAME}-${port}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
  fi
}

# Add the Codespaces origin to gateway.controlUi.allowedOrigins so the
# browser Control UI is not blocked by the gateway's CORS check.
configure_allowed_origins() {
  local origin
  origin=$(codespace_origin)
  [ -n "$origin" ] || return 0   # not in Codespaces — nothing to do

  info "Allowing Control UI origin: $origin"
  openclaw configure set gateway.controlUi.allowedOrigins "$origin" 2>/dev/null || \
    warn "Could not set allowedOrigins automatically — add '$origin' manually via: openclaw configure"
}

# ── step 2 : start gateway ────────────────────────────────────────────────────
start_gateway() {
  local port="${OPENCLAW_PORT:-18789}"
  section "Step 2 — Starting OpenClaw Gateway (port $port)"

  # Ensure the Codespaces origin is whitelisted before starting
  configure_allowed_origins

  # Check if already running
  if openclaw gateway status 2>/dev/null | grep -qi "running"; then
    info "Gateway is already running."
    open_ui
    return
  fi

  info "Starting gateway in background on port $port..."
  nohup openclaw gateway --port "$port" > /tmp/openclaw-gateway.log 2>&1 &
  GATEWAY_PID=$!
  echo "$GATEWAY_PID" > /tmp/openclaw-gateway.pid

  # Wait up to 15 s for the gateway to come up
  local waited=0
  until openclaw gateway status 2>/dev/null | grep -qi "running" || [ "$waited" -ge 15 ]; do
    sleep 1; (( waited++ )) || true
  done

  if openclaw gateway status 2>/dev/null | grep -qi "running"; then
    info "Gateway is up (PID $GATEWAY_PID, log: /tmp/openclaw-gateway.log)."
    open_ui
  else
    warn "Gateway may not have started yet — check /tmp/openclaw-gateway.log"
  fi
}

# ── fix origins (standalone) ─────────────────────────────────────────────────
fix_origins() {
  section "Fix Control UI Allowed Origins"
  configure_allowed_origins
  info "Restarting gateway to apply origin change..."
  openclaw gateway restart 2>/dev/null || {
    warn "Could not restart via 'openclaw gateway restart'. Stopping and starting manually..."
    openclaw gateway stop 2>/dev/null || true
    sleep 1
    local port="${OPENCLAW_PORT:-18789}"
    nohup openclaw gateway --port "$port" >> /tmp/openclaw-gateway.log 2>&1 &
    echo $! > /tmp/openclaw-gateway.pid
    sleep 2
  }
  open_ui
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
  --install          Install OpenClaw and persist auth token to shell profile
  --start            Start the gateway and print the auto-auth URL
  --status           Show gateway status
  --open             Print (and copy) the auto-auth browser URL
  --fix-origins      Add Codespaces origin to allowedOrigins and restart gateway
  --login-whatsapp   Log in via WhatsApp
  --configure-model  Select AI model interactively
  --all              Run all steps in sequence (default)
  --port PORT        Gateway port (default: 18789)
  -h, --help         Show this help

Environment:
  OPENCLAW_PORT            Override gateway port (default: 18789)
  OPENCLAW_GATEWAY_TOKEN   Gateway auth token (auto-persisted after install)

Examples:
  # Run everything (install → start → status → whatsapp → model)
  bash setup-openclaw.sh --all

  # Just print the authenticated URL for the browser
  bash setup-openclaw.sh --open

  # Start gateway on custom port
  bash setup-openclaw.sh --start --port 9000
EOF
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  local do_install=false do_start=false do_status=false
  local do_whatsapp=false do_model=false do_all=false
  local do_open=false do_fix_origins=false

  if [ $# -eq 0 ]; then do_all=true; fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --install)          do_install=true ;;
      --start)            do_start=true ;;
      --status)           do_status=true ;;
      --open)             do_open=true ;;
      --fix-origins)      do_fix_origins=true ;;
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
  $do_open          && open_ui
  $do_fix_origins   && fix_origins
  $do_whatsapp      && login_whatsapp
  $do_model         && configure_model

  section "Done"
  info "OpenClaw setup complete."
  info "Gateway log: /tmp/openclaw-gateway.log"
  info "Run 'openclaw --help' to explore available commands."
}

main "$@"
