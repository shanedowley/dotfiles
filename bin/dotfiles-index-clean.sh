#!/usr/bin/env bash
set -euo pipefail

DOTGIT=(/usr/bin/git --git-dir="$HOME/.dotfiles" --work-tree="$HOME")

echo "==> Removing bad tracked files from bare repo index (keeping working files in place where possible)"

# Obvious junk
"${DOTGIT[@]}" rm --cached --ignore-unmatch \
  .DS_Store \
  nvim/.DS_Store \
  nvim/lua/.DS_Store \
  nvim/lua/plugins/.DS_Store \
  nvim/lua/snippets/.DS_Store \
  nvim/lua/plugins/tests.lua.bak \
  .config/nvim/lua/plugins/notify.lua.org

# Neovim runtime/cache/state that should not be versioned
"${DOTGIT[@]}" rm -r --cached --ignore-unmatch \
  .config/nvim/nvim \
  .config/nvim/gem \
  .config/sketchybar/timer_state

# Legacy duplicate top-level nvim config tree (canonical config is .config/nvim)
"${DOTGIT[@]}" rm -r --cached --ignore-unmatch \
  nvim

# Top-level duplicate files that should not exist beside canonical dotfiles
"${DOTGIT[@]}" rm --cached --ignore-unmatch \
  gitconfig \
  gitignore \
  clang-format

# Remove accidental top-level duplicate, NOT the real bin version
if "${DOTGIT[@]}" ls-files --error-unmatch codex-aliases.sh >/dev/null 2>&1; then
  "${DOTGIT[@]}" rm --cached codex-aliases.sh
fi

echo "==> Done. Review with:"
echo "    dotgit status --short"
