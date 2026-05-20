# openclaw-ws-1

A GitHub Codespaces workspace for running the [OpenClaw](https://openclaw.ai) AI gateway.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Launching OpenClaw after Codespace is Ready](#launching-openclaw-after-codespace-is-ready)
- [Setup Script Reference](#setup-script-reference)
- [What the Script Does](#what-the-script-does)
- [Manual Commands](#manual-commands)
- [Keeping Your Codespace in Sync](#keeping-your-codespace-in-sync)
- [Logs](#logs)

---

## Quick Start

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/yennanliu/openclaw-ws-1)

1. Click **Code → Codespaces → Create codespace on main** (or the badge above).
2. Wait for the container to build — OpenClaw is installed automatically via `postCreate.sh`.
3. Open a terminal (`Ctrl+\`` or **Terminal → New Terminal**) and launch:

```bash
# Full setup: start gateway → WhatsApp login → model selection
bash scripts/setup-openclaw.sh --all
```

---

## Launching OpenClaw after Codespace is Ready

`postCreate.sh` runs automatically during container creation and installs OpenClaw,
but it does **not** start the gateway or run interactive steps (those require a live terminal).

Once the codespace is ready, open a terminal and run:

```bash
# Option A — run all steps in sequence (recommended for first time)
bash scripts/setup-openclaw.sh --all

# Option B — step by step
bash scripts/setup-openclaw.sh --start            # start gateway on port 18789
bash scripts/setup-openclaw.sh --status           # confirm it is up
bash scripts/setup-openclaw.sh --login-whatsapp   # scan QR / follow on-screen prompts
bash scripts/setup-openclaw.sh --configure-model  # pick your AI model
```

Port `18789` is automatically forwarded by Codespaces — VS Code will show an
**"Open in Browser"** pop-up when the gateway comes up.

---

## Setup Script Reference

`scripts/setup-openclaw.sh` automates each step individually or all at once.

```bash
# Install OpenClaw only (skipped if already installed)
bash scripts/setup-openclaw.sh --install

# Start the gateway (default port: 18789)
bash scripts/setup-openclaw.sh --start

# Check gateway status
bash scripts/setup-openclaw.sh --status

# Log in via WhatsApp (interactive)
bash scripts/setup-openclaw.sh --login-whatsapp

# Choose AI model (interactive)
bash scripts/setup-openclaw.sh --configure-model

# Start on a custom port
bash scripts/setup-openclaw.sh --start --port 9000

# Run all steps
bash scripts/setup-openclaw.sh --all
```

You can also set the port via environment variable:

```bash
OPENCLAW_PORT=9000 bash scripts/setup-openclaw.sh --all
```

---

## What the Script Does

| Step | Command | Notes |
|------|---------|-------|
| Install | `curl -fsSL https://openclaw.ai/install.sh \| bash` | Skipped if already installed |
| Start gateway | `openclaw gateway --port 18789` | Runs in background; port 18789 is auto-forwarded in Codespaces |
| Status | `openclaw gateway status` | |
| WhatsApp login | `openclaw channels login --channel whatsapp` | Interactive — follow on-screen QR/instructions |
| Model select | `openclaw configure --section model` | Interactive |

---

## Manual Commands

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

# Select AI model (interactive)
openclaw configure --section model
```

---

## Keeping Your Codespace in Sync

Codespaces do **not** auto-sync when the repo is updated. Use the table below to
apply changes depending on what was modified.

| What changed | How to sync |
|---|---|
| Code / scripts (e.g. `scripts/`) | `git pull origin main` in the terminal |
| Devcontainer config (`.devcontainer/devcontainer.json` or `postCreate.sh`) | Rebuild the container (see below) |
| Starting a brand-new codespace | Always clones the latest `main` automatically |

### Syncing code changes

```bash
git pull origin main
```

### Rebuilding the container after devcontainer changes

If `.devcontainer/devcontainer.json` or `postCreate.sh` is updated, a `git pull`
alone won't re-run the setup. You must rebuild the container:

- **VS Code**: `Ctrl+Shift+P` → `Codespaces: Rebuild Container` → Enter
- **GitHub web UI**: three-dot menu on your codespace → **Rebuild**

Use **Full Rebuild** to clear all cached Docker layers and start completely clean.

> After a rebuild the container re-runs `postCreate.sh`, which reinstalls OpenClaw
> if needed. Then follow the [Launching](#launching-openclaw-after-codespace-is-ready)
> steps again.

---

## Logs

Gateway logs are written to `/tmp/openclaw-gateway.log` when started via the setup script.

```bash
tail -f /tmp/openclaw-gateway.log
```
