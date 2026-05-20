#!/usr/bin/env bash
# test-setup-openclaw.sh — unit tests for setup-openclaw.sh using a mocked openclaw binary
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup-openclaw.sh"
MOCK_BIN="$(mktemp -d)"
CALL_LOG="$(mktemp)"
PASS=0
FAIL=0

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; (( PASS++ )) || true; }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; (( FAIL++ )) || true; }
suite() { echo -e "\n${CYAN}$1${NC}"; }

# ── mock helpers ───────────────────────────────────────────────────────────────

install_mock_openclaw() {
  # Mock openclaw that logs every call and returns sensible defaults.
  # Write the script with the CALL_LOG path expanded at generation time
  # (avoids sed -i portability issues between macOS and Linux).
  local log="$CALL_LOG"
  {
    echo '#!/usr/bin/env bash'
    echo "echo \"openclaw \$*\" >> \"$log\""
    echo 'case "$1 $2" in'
    echo '  "gateway status") echo "Status: running" ;;'
    echo '  "--version")      echo "openclaw 1.0.0-mock" ;;'
    echo 'esac'
    echo 'exit 0'
  } > "$MOCK_BIN/openclaw"
  chmod +x "$MOCK_BIN/openclaw"
}

install_mock_openclaw_missing() {
  # Simulate openclaw not installed: remove mock binary
  rm -f "$MOCK_BIN/openclaw"
}

install_mock_curl() {
  # Mock curl: when fetching the openclaw installer, emit a shell script that
  # creates a stub openclaw binary, simulating a real install.
  # All variable references are built explicitly to avoid heredoc quoting issues.
  local log="$CALL_LOG"
  {
    echo '#!/usr/bin/env bash'
    echo 'if [[ "$*" == *"openclaw.ai/install.sh"* ]]; then'
    echo '  mkdir -p "$HOME/.local/bin"'
    echo '  {'
    echo '    echo '"'"'#!/usr/bin/env bash'"'"''
    echo "    echo \"echo \\\"openclaw \\\$*\\\" >> \\\"$log\\\"\""
    echo '    echo '"'"'case "$1 $2" in'"'"''
    echo '    echo '"'"'  "gateway status") echo "Status: running" ;;'"'"''
    echo '    echo '"'"'  "--version")      echo "openclaw 1.0.0-mock" ;;'"'"''
    echo '    echo '"'"'esac'"'"''
    echo '    echo '"'"'exit 0'"'"''
    echo '  } > "$HOME/.local/bin/openclaw"'
    echo '  chmod +x "$HOME/.local/bin/openclaw"'
    echo '  echo "OpenClaw installed (mock)"'
    echo 'else'
    echo '  /usr/bin/curl "$@"'
    echo 'fi'
  } > "$MOCK_BIN/curl"
  chmod +x "$MOCK_BIN/curl"
}

reset_log() { > "$CALL_LOG"; }

called_with() { grep -qF "openclaw $1" "$CALL_LOG"; }

cleanup() {
  rm -rf "$MOCK_BIN" "$CALL_LOG"
}
trap cleanup EXIT

# Prepend mock bin to PATH for all tests
export PATH="$MOCK_BIN:$PATH"

# ── test cases ─────────────────────────────────────────────────────────────────

suite "Syntax & flags"

  if bash -n "$SETUP_SCRIPT" 2>/dev/null; then
    pass "script syntax is valid"
  else
    fail "script has syntax errors"
  fi

  output=$(bash "$SETUP_SCRIPT" --help 2>&1)
  if echo "$output" | grep -q "Usage:"; then
    pass "--help prints usage"
  else
    fail "--help did not print usage"
  fi

  if bash "$SETUP_SCRIPT" --unknown-flag 2>/dev/null; then
    fail "--unknown-flag should exit non-zero"
  else
    pass "--unknown-flag exits with error"
  fi

suite "Install step"

  install_mock_openclaw
  reset_log
  bash "$SETUP_SCRIPT" --install 2>/dev/null
  if ! grep -q "openclaw.ai" "$CALL_LOG" 2>/dev/null; then
    pass "install skipped (openclaw already on PATH)"
  else
    fail "install ran curl even though openclaw was already present"
  fi

  install_mock_openclaw_missing
  install_mock_curl
  reset_log
  bash "$SETUP_SCRIPT" --install 2>/dev/null || true
  if grep -q "openclaw" "$CALL_LOG" 2>/dev/null || \
     [ -f "$HOME/.local/bin/openclaw" ]; then
    pass "install ran when openclaw was missing"
  else
    fail "install did not run when openclaw was missing"
  fi
  # Restore mock openclaw for remaining tests
  install_mock_openclaw

suite "Status step"

  reset_log
  bash "$SETUP_SCRIPT" --status 2>/dev/null
  if called_with "gateway status"; then
    pass "--status called 'openclaw gateway status'"
  else
    fail "--status did not call 'openclaw gateway status'"
  fi

suite "Start step"

  reset_log
  # Mock returns "running", so start should detect existing gateway and skip nohup
  bash "$SETUP_SCRIPT" --start 2>/dev/null
  if called_with "gateway status"; then
    pass "--start checked gateway status"
  else
    fail "--start did not check gateway status"
  fi

suite "Custom port"

  reset_log
  output=$(bash "$SETUP_SCRIPT" --start --port 9999 2>&1) || true
  if echo "$output" | grep -q "9999"; then
    pass "--port 9999 reflected in output"
  else
    fail "--port 9999 not reflected in output"
  fi

  reset_log
  output=$(OPENCLAW_PORT=8888 bash "$SETUP_SCRIPT" --start 2>&1) || true
  if echo "$output" | grep -q "8888"; then
    pass "OPENCLAW_PORT env var reflected in output"
  else
    fail "OPENCLAW_PORT env var not reflected in output"
  fi

# ── summary ───────────────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
echo -e "Results: ${GREEN}$PASS passed${NC}, $([ $FAIL -eq 0 ] && echo -e "${GREEN}" || echo -e "${RED}")$FAIL failed${NC}"
echo "─────────────────────────────────"

[ "$FAIL" -eq 0 ] || exit 1
