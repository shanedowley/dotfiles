#!/usr/bin/env bash
set -euo pipefail

# weekly-hygiene.sh
#
# Purpose:
#   Keep Shane's dotfiles/home-config system tidy with a repeatable audit loop.
#
# Modes:
#   audit   (default)  -> pull, inspect, log, and exit non-zero if attention needed
#   commit            -> same checks, then commit safe tracked changes only
#
# Notes:
#   - This script is intentionally conservative.
#   - It audits only the managed dotfiles surface, not the whole home directory.
#   - It excludes known generated/runtime subtrees from audit.
#   - It will NOT auto-commit if it sees suspicious junk/untracked files.
#   - It only auto-commits tracked modifications/deletions in commit mode.

MODE="${1:-audit}"

DOTGIT_DIR="$HOME/.dotfiles"
WORK_TREE="$HOME"
GIT_BIN="/usr/bin/git"
LOG_DIR="$HOME/.local/state/dotfiles"
LOG_FILE="$LOG_DIR/weekly-hygiene.log"

# Global state for parse_status (explicit for Bash 3.2 + set -u)
CLEAN=1
SUSPICIOUS=()
UNTRACKED=()
TRACKED=()

mkdir -p "$LOG_DIR"

dotgit() {
  "$GIT_BIN" --git-dir="$DOTGIT_DIR" --work-tree="$WORK_TREE" "$@"
}

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $*"
  exit 1
}

require_repo() {
  [[ -d "$DOTGIT_DIR" ]] || die "Bare repo not found at $DOTGIT_DIR"
}

pull_fast_forward() {
  log "Pulling latest changes from origin/main"
  if ! dotgit pull --ff-only; then
    die "dotgit pull --ff-only failed"
  fi
}

managed_status() {
  local -a include_paths=(
    ".zshrc"
    ".gitconfig"
    ".gitignore"
    ".config/nvim"
    ".config/tmux"
    ".config/starship.toml"
    ".config/ghostty"
    ".config/aerospace"
    ".config/karabiner/karabiner.json"
    ".config/karabiner/assets/complex_modifications"
    ".config/sketchybar"
    "bin"
    "install.sh"
    "new_install_guide.md"
  )

  local -a existing_paths=()
  local p
  for p in "${include_paths[@]}"; do
    [[ -e "$WORK_TREE/$p" ]] && existing_paths+=("$p")
  done

  local -a exclude_paths=(
    ':(exclude).config/nvim/nvim/**'
    ':(exclude).config/nvim/gem/**'
    ':(exclude).config/sketchybar/timer_state'
    ':(exclude)**/.DS_Store'
    ':(exclude)**/*.bak'
    ':(exclude)**/*.org'
    ':(exclude)**/*~'
    ':(exclude)**/*.swp'
    ':(exclude)**/*.swo'
    ':(exclude)**/*.swn'
    ':(exclude)**/._*'
    ':(exclude)**/__MACOSX/**'
  )

  dotgit status --porcelain=v1 --untracked-files=all -- "${existing_paths[@]}" "${exclude_paths[@]}"
}

is_suspicious_path() {
  local p="$1"

  case "$p" in
    *.DS_Store|*.bak|*.org|*~|*.swp|*.swo|*.swn|._*)
      return 0
      ;;
    .config/nvim/nvim/*|.config/nvim/gem/*|.config/sketchybar/timer_state|__MACOSX/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# parse_status populates these globals for Bash 3.2 compatibility:
#   CLEAN
#   SUSPICIOUS[]
#   UNTRACKED[]
#   TRACKED[]
parse_status() {
  local status_output="$1"

  CLEAN=1
  SUSPICIOUS=()
  UNTRACKED=()
  TRACKED=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    CLEAN=0

    local xy="${line:0:2}"
    local path="${line:3}"

    if is_suspicious_path "$path"; then
      SUSPICIOUS+=("$line")
    fi

    if [[ "$xy" == '??' ]]; then
      UNTRACKED+=("$line")
    else
      TRACKED+=("$line")
    fi
  done <<< "$status_output"
}

show_group() {
  local title="$1"
  shift
  local items=("$@")

  [[ ${#items[@]} -eq 0 ]] && return 0

  log "$title"
  local item
  for item in "${items[@]}"; do
    [[ -n "$item" ]] || continue
    printf '  %s\n' "$item" | tee -a "$LOG_FILE"
  done
}

commit_safe_tracked_changes() {
  local status_output="$1"

  [[ -n "$status_output" ]] || return 0

  log "Staging tracked updates only"
  dotgit add -u -- \
    .zshrc \
    .gitconfig \
    .gitignore \
    .config/nvim \
    .config/tmux \
    .config/starship.toml \
    .config/ghostty \
    .config/aerospace \
    .config/karabiner/karabiner.json \
    .config/karabiner/assets/complex_modifications \
    .config/sketchybar \
    bin \
    install.sh \
    new_install_guide.md

  if dotgit diff --cached --quiet; then
    log "No staged tracked changes to commit"
    return 0
  fi

  local msg="weekly hygiene ($(date +%Y-%m-%d))"
  log "Creating commit: $msg"
  dotgit commit -m "$msg"
  log "Pushing to origin/main"
  dotgit push origin main
}

main() {
  case "$MODE" in
    audit|commit) ;;
    *)
      die "Unknown mode '$MODE'. Use: audit | commit"
      ;;
  esac

  require_repo
  log "Starting weekly hygiene in mode: $MODE"

  pull_fast_forward

  local status
  status="$(managed_status)"

  parse_status "$status"

  local clean="${CLEAN:-1}"

  if [[ "$clean" -eq 1 ]]; then
    log "Managed surface clean. No action needed."
    exit 0
  fi

  show_group "Tracked changes detected:" "${TRACKED[@]-}"
  show_group "Untracked files detected within managed surface:" "${UNTRACKED[@]-}"
  show_group "Suspicious paths detected:" "${SUSPICIOUS[@]-}"

  if [[ ${#SUSPICIOUS[@]} -gt 0 ]]; then
    die "Suspicious files present in managed surface. Review manually before any commit."
  fi

  if [[ ${#UNTRACKED[@]} -gt 0 ]]; then
    die "Untracked files present in managed surface. Review manually before any commit."
  fi

  if [[ "$MODE" == "audit" ]]; then
    die "Tracked changes detected in managed surface. Review and run commit mode if appropriate."
  fi

  commit_safe_tracked_changes "$status"
  log "Weekly hygiene complete."
}

main "$@"