#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing OpenClaw build dependencies..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  build-essential \
  cmake \
  git \
  libsdl2-dev \
  libsdl2-image-dev \
  libsdl2-mixer-dev \
  libsdl2-ttf-dev \
  libsdl2-gfx-dev \
  libboost-dev \
  timidity \
  freepats

echo "==> Cloning OpenClaw..."
git clone --depth 1 https://github.com/pjasicek/OpenClaw.git

echo "==> Configuring build..."
cmake -S OpenClaw -B build -DCMAKE_BUILD_TYPE=Release

echo ""
echo "Done! To build OpenClaw run:"
echo "  cmake --build build -j\$(nproc)"
echo ""
echo "NOTE: You still need the original CLAW.REZ game asset to play."
echo "See OpenClaw/README.md for details."
