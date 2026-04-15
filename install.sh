#!/usr/bin/env bash
set -euo pipefail

REPO_URL="git@github.com:shanedowley/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles-checkout-backup"
ZSHRC="$HOME/.zshrc"
DOTGIT_BIN="/usr/bin/git"

log() {
  printf '\n==> %s\n' "$1"
}

warn() {
  printf '\n[warn] %s\n' "$1" >&2
}

die() {
  printf '\n[error] %s\n' "$1" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

append_line_if_missing() {
  local line="$1"
  local file="$2"

  touch "$file"
  grep -Fqx "$line" "$file" || printf '%s\n' "$line" >> "$file"
}

dotgit() {
  "$DOTGIT_BIN" --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"
}

ensure_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This bootstrap is for macOS only"
}

ensure_zsh_exists() {
  have_cmd zsh || die "zsh not found"
}

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools already installed"
    return
  fi

  log "Installing Xcode Command Line Tools"
  xcode-select --install || true

  cat <<'EOF'

Xcode Command Line Tools install has been triggered.
macOS may show a GUI prompt.

When installation finishes, re-run this script.

EOF
  exit 0
}

ensure_homebrew() {
  if have_cmd brew; then
    log "Homebrew already installed"
    return
  fi

  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

setup_brew_shellenv() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    die "Homebrew installed but brew not found in expected locations"
  fi
}

install_core_packages() {
  log "Installing core packages"
  brew install git neovim tmux ripgrep fd
}

ensure_dotgit_alias_in_zshrc() {
  local alias_line="alias dotgit='/usr/bin/git --git-dir=\$HOME/.dotfiles --work-tree=\$HOME'"
  append_line_if_missing "$alias_line" "$ZSHRC"
}

ensure_github_ssh_ready() {
  log "Checking GitHub SSH access"

  local ssh_output
  ssh_output="$(ssh -T git@github.com 2>&1 || true)"

  if grep -q "successfully authenticated" <<<"$ssh_output"; then
    log "GitHub SSH authentication is working"
    return
  fi

  cat <<EOF

[error] GitHub SSH is not set up on this machine.

Current SSH check output:
$ssh_output

Do this first:
  ssh-keygen -t ed25519 -C "your_email@example.com"
  pbcopy < ~/.ssh/id_ed25519.pub

Then add the key to GitHub:
  https://github.com/settings/keys

After that, re-run this script.

EOF
  exit 1
}

clone_bare_repo_if_needed() {
  if [[ -d "$DOTFILES_DIR" ]]; then
    log "Bare dotfiles repo already exists at $DOTFILES_DIR"
    return
  fi

  log "Cloning bare dotfiles repo"
  git clone --bare "$REPO_URL" "$DOTFILES_DIR"
}

backup_conflicting_files_and_checkout() {
  local checkout_log
  checkout_log="$(mktemp)"

  log "Checking out dotfiles into \$HOME"

  if dotgit checkout >"$checkout_log" 2>&1; then
    log "Dotfiles checked out cleanly"
    rm -f "$checkout_log"
    return
  fi

  warn "Checkout reported conflicts. Backing up conflicting files."
  mkdir -p "$BACKUP_DIR"

  awk '
    BEGIN { capture=0 }
    /^error: The following untracked working tree files would be overwritten by checkout:/ { capture=1; next }
    capture && /^Please move or remove them before you switch branches./ { capture=0; next }
    capture && /^[[:space:]]+/ {
      sub(/^[[:space:]]+/, "", $0)
      print
    }
  ' "$checkout_log" | while IFS= read -r path; do
    [[ -z "$path" ]] && continue

    local src="$HOME/$path"
    local dst="$BACKUP_DIR/$path"

    if [[ -e "$src" || -L "$src" ]]; then
      mkdir -p "$(dirname "$dst")"
      mv "$src" "$dst"
      printf 'Moved conflicting path to backup: %s\n' "$path"
    fi
  done

  if ! dotgit checkout; then
    cat "$checkout_log" >&2 || true
    rm -f "$checkout_log"
    die "dotgit checkout still failed after backing up conflicts"
  fi

  rm -f "$checkout_log"
}

configure_bare_repo() {
  log "Configuring bare repo"
  dotgit config --local status.showUntrackedFiles no
}

print_next_steps() {
  cat <<EOF

Bootstrap complete.

What was done:
- ensured macOS environment
- ensured Xcode Command Line Tools
- ensured Homebrew
- installed core packages: git, neovim, tmux, ripgrep, fd
- verified GitHub SSH access
- cloned bare repo to: $DOTFILES_DIR
- checked out dotfiles into: $HOME
- configured dotgit alias in: $ZSHRC
- configured bare repo to hide untracked files in status

Backup directory for any checkout conflicts:
$BACKUP_DIR

Now do this:
  exec zsh

Then verify:
  dotgit status
  nvim --version
  tmux -V

EOF
}

main() {
  ensure_macos
  ensure_zsh_exists
  ensure_xcode_clt
  ensure_homebrew
  setup_brew_shellenv
  install_core_packages
  ensure_github_ssh_ready
  ensure_dotgit_alias_in_zshrc
  clone_bare_repo_if_needed
  backup_conflicting_files_and_checkout
  configure_bare_repo
  print_next_steps
}

main "$@"
