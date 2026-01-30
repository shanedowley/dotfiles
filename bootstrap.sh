#!/usr/bin/env bash
set -e

echo "🔧 Bootstrapping dotfiles..."

# Ensure directories exist
mkdir -p "$HOME/.config"

# Symlinks (only where intentional)
ln -sf "$HOME/dotfiles/gitconfig" "$HOME/.gitconfig"

# Homebrew sanity check
if ! command -v brew >/dev/null 2>&1; then
  echo "⚠️ Homebrew not installed. Install it first:"
  echo "   https://brew.sh"
else
  echo "✅ Homebrew found"
fi

echo "✅ Bootstrap complete"
echo "👉 Next steps:"
echo "   - open a new terminal"
echo "   - run: dotsync"
