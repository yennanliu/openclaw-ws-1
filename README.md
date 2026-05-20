# openclaw-ws-1

A GitHub Codespaces workspace for building [OpenClaw](https://github.com/pjasicek/OpenClaw) — an open-source reimplementation of the 1997 platformer *Claw*.

## Quick Start with GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/YOUR_USERNAME/openclaw-ws-1)

1. Click **Code → Codespaces → Create codespace on main** (or the badge above after pushing to GitHub).
2. Wait for the container to build — it installs all dependencies and clones OpenClaw automatically.
3. Build:
   ```bash
   cmake --build build -j$(nproc)
   ```

## What gets installed

The `postCreate.sh` script runs automatically inside the codespace and installs:

| Package | Purpose |
|---|---|
| `cmake`, `build-essential` | Build toolchain |
| `libsdl2-dev` | Graphics & input |
| `libsdl2-image-dev` | Image loading |
| `libsdl2-mixer-dev` | Audio |
| `libsdl2-ttf-dev` | Font rendering |
| `libsdl2-gfx-dev` | Extra SDL graphics |
| `libboost-dev` | Boost utilities |
| `timidity`, `freepats` | MIDI playback |

OpenClaw is cloned into `OpenClaw/` and CMake is pre-configured in `build/`.

## Running the game

You still need the original **CLAW.REZ** asset file from the retail game. Place it in `build/` and follow the instructions in `OpenClaw/README.md`.

## Local development

To replicate the setup locally on Ubuntu/Debian:

```bash
bash .devcontainer/postCreate.sh
cmake --build build -j$(nproc)
```
