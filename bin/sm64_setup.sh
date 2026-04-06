#!/bin/bash
set -e

echo "== Super Mario 64 Mac Setup =="

xcode-select -p >/dev/null 2>&1 || xcode-select --install

if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew install git python sdl2

cd ~

if [ -d "sm64ex/.git" ]; then
  echo "sm64ex repo already exists, using it."
elif [ -d "sm64ex" ]; then
  echo "ERROR: ~/sm64ex exists but is not a git repo."
  echo "Rename or remove it, then rerun this script."
  exit 1
else
  git clone https://github.com/sm64pc/sm64ex.git
fi

cd ~/sm64ex

echo
echo "Place your ROM here as:"
echo "~/sm64ex/baserom.us.z64"
echo

read -p "Press ENTER once the ROM is in place..."

if [ ! -f "baserom.us.z64" ]; then
  echo "ERROR: baserom.us.z64 not found."
  exit 1
fi

make -j"$(sysctl -n hw.ncpu)"

echo
echo "Build complete."
echo "Run with:"
echo "./build/us_pc/sm64.us"