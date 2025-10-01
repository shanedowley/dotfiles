#!/usr/bin/env bash
set -e

DOTFILES_DIR="$HOME/dotfiles"

# List of files/folders to symlink
FILES=(
  ".zshrc"
  ".gitconfig"
  ".config/nvim"
)

echo "Setting up dotfiles from $DOTFILES_DIR"

for file in "${FILES[@]}"; do
  target="$HOME/$file"
  source="$DOTFILES_DIR/$file"

  # Create parent directory if missing
  mkdir -p "$(dirname "$target")"

  # Backup existing file if it exists and is not a symlink
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "Backing up $target to $target.backup"
    mv "$target" "$target.backup"
  fi

  # Remove existing symlink if pointing elsewhere
  if [ -L "$target" ]; then
    rm "$target"
  fi

  # Create symlink
  echo "Linking $source → $target"
  ln -s "$source" "$target"
done

echo "✅ Dotfiles setup complete!"
