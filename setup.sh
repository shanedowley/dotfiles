#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup"
IGNORE=("README.md" "LICENSE" ".gitignore" "setup.sh" ".git")

mkdir -p "$BACKUP_DIR"

is_ignored() {
  local name="$1"
  for ignore in "${IGNORE[@]}"; do
    if [[ "$name" == "$ignore" ]]; then
      return 0
    fi
  done
  return 1
}

for path in "$DOTFILES_DIR"/*; do
  name=$(basename "$path")

  if is_ignored "$name"; then
    echo "Skipping $name"
    continue
  fi

  # Decide target
  if [ -d "$path" ] && [[ "$name" =~ ^(nvim|alacritty|tmux|zellij)$ ]]; then
    target="$HOME/.config/$name"
  else
    target="$HOME/.$name"
  fi

  # Backup if needed
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "Backing up existing $target → $BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/"
  fi

  # Link
  echo "Linking $path → $target"
  ln -sfn "$path" "$target"
done

echo "✅ Dotfiles setup complete"
