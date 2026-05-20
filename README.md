# openclaw-ws-1

A GitHub Codespaces workspace for running the [OpenClaw](https://openclaw.ai) AI gateway.

## Quick Start with GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/yennanliu/openclaw-ws-1)

1. Click **Code → Codespaces → Create codespace on main** (or the badge above).
2. Wait for the container to build — OpenClaw is installed automatically.
3. Run the setup script:

```bash
# Full setup: start gateway → WhatsApp login → model selection
bash scripts/setup-openclaw.sh --all
```

## Setup script

`scripts/setup-openclaw.sh` automates each step individually or all at once.

```bash
# Install OpenClaw only
bash scripts/setup-openclaw.sh --install

# Start the gateway (default port: 18789)
bash scripts/setup-openclaw.sh --start

# Check gateway status
bash scripts/setup-openclaw.sh --status

# Log in via WhatsApp (interactive)
bash scripts/setup-openclaw.sh --login-whatsapp

# Choose AI model (interactive)
bash scripts/setup-openclaw.sh --configure-model

# Custom gateway port
bash scripts/setup-openclaw.sh --start --port 9000
```

## What the script does

| Step | Command | Notes |
|------|---------|-------|
| Install | `curl -fsSL https://openclaw.ai/install.sh \| bash` | Skipped if already installed |
| Start gateway | `openclaw gateway --port 18789` | Runs in background, port 18789 is auto-forwarded in Codespaces |
| Status | `openclaw gateway status` | |
| WhatsApp login | `openclaw channels login --channel whatsapp` | Interactive — follow on-screen QR/instructions |
| Model select | `openclaw configure --section model` | Interactive |

## Manual commands

```bash
# Install
curl -fsSL https://openclaw.ai/install.sh | bash

# Start gateway (foreground)
openclaw gateway --port 18789

# Check gateway status
openclaw gateway status

# WhatsApp login
openclaw channels login --channel whatsapp

# Check WhatsApp connectivity
curl -I https://web.whatsapp.com/

# Select model (interactive)
openclaw configure --section model
```

## Logs

Gateway logs are written to `/tmp/openclaw-gateway.log` when started via the setup script.
