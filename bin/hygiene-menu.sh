#!/usr/bin/env bash
set -euo pipefail

# hygiene-menu.sh
#
# Simple CLI menu for Shane's dotfiles hygiene workflow.
#
# Supports:
#   - run audit
#   - run commit (tracked changes only)
#   - track a new managed file explicitly
#   - view log
#   - install weekly launchd schedule (Monday 10:00 local)
#   - uninstall schedule
#   - check schedule status
#
# Expected companion script:
#   ~/bin/weekly-hygiene.sh

HYGIENE_SCRIPT="$HOME/bin/weekly-hygiene.sh"
LOG_FILE="$HOME/.local/state/dotfiles/weekly-hygiene.log"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_LABEL="com.shanedowley.weekly-hygiene"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_LABEL.plist"
DOTGIT_DIR="$HOME/.dotfiles"
WORK_TREE="$HOME"
GIT_BIN="/usr/bin/git"

dotgit() {
  "$GIT_BIN" --git-dir="$DOTGIT_DIR" --work-tree="$WORK_TREE" "$@"
}

ensure_hygiene_script() {
  [[ -x "$HYGIENE_SCRIPT" ]] || {
    echo
    echo "ERROR: Expected executable script not found:"
    echo "  $HYGIENE_SCRIPT"
    echo
    exit 1
  }
}

ensure_repo() {
  [[ -d "$DOTGIT_DIR" ]] || {
    echo
    echo "ERROR: Bare dotfiles repo not found:"
    echo "  $DOTGIT_DIR"
    echo
    exit 1
  }
}

pause() {
  echo
  read -r -p "Press Enter to continue..."
}

install_schedule() {
  ensure_hygiene_script
  mkdir -p "$LAUNCH_AGENTS_DIR"
  mkdir -p "$HOME/.local/state/dotfiles"

  cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>

    <key>ProgramArguments</key>
    <array>
      <string>/bin/zsh</string>
      <string>-lc</string>
      <string>$HYGIENE_SCRIPT audit</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
      <key>Weekday</key>
      <integer>1</integer>
      <key>Hour</key>
      <integer>10</integer>
      <key>Minute</key>
      <integer>0</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>$HOME/.local/state/dotfiles/weekly-hygiene.launchd.out.log</string>

    <key>StandardErrorPath</key>
    <string>$HOME/.local/state/dotfiles/weekly-hygiene.launchd.err.log</string>

    <key>RunAtLoad</key>
    <false/>
  </dict>
</plist>
EOF

  launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
  launchctl load "$PLIST_PATH"

  echo
  echo "Weekly hygiene schedule installed."
  echo "Runs every Monday at 10:00 local time."
  echo "LaunchAgent:"
  echo "  $PLIST_PATH"
}

uninstall_schedule() {
  if [[ -f "$PLIST_PATH" ]]; then
    launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
    rm -f "$PLIST_PATH"
    echo
    echo "Weekly hygiene schedule removed."
  else
    echo
    echo "No installed schedule found at:"
    echo "  $PLIST_PATH"
  fi
}

show_schedule_status() {
  echo
  if [[ -f "$PLIST_PATH" ]]; then
    echo "LaunchAgent file exists:"
    echo "  $PLIST_PATH"
    echo
    echo "launchctl list status:"
    launchctl list | grep "$PLIST_LABEL" || echo "  Label not currently loaded in launchctl list output."
  else
    echo "No installed schedule found."
  fi
}

run_audit() {
  ensure_hygiene_script
  echo
  "$HYGIENE_SCRIPT" audit || true
}

run_commit() {
  ensure_hygiene_script
  echo
  "$HYGIENE_SCRIPT" commit || true
}

track_new_file() {
  ensure_repo

  echo
  echo "Track a new managed file"
  echo "Enter a path relative to HOME, for example:"
  echo "  bin/hygiene-menu.sh"
  echo "  install.sh"
  echo "  new_install_guide.md"
  echo

  local relpath
  read -r -p "Relative path: " relpath

  [[ -n "$relpath" ]] || {
    echo
    echo "No path entered."
    return 0
  }

  case "$relpath" in
    /*)
      echo
      echo "Please enter a path relative to HOME, not an absolute path."
      return 1
      ;;
  esac

  local fullpath="$HOME/$relpath"

  if [[ ! -e "$fullpath" ]]; then
    echo
    echo "Path does not exist:"
    echo "  $fullpath"
    return 1
  fi

  echo
  echo "About to track:"
  echo "  $relpath"
  read -r -p "Proceed? [y/N]: " confirm

  case "$confirm" in
    y|Y) ;;
    *)
      echo
      echo "Cancelled."
      return 0
      ;;
  esac

  dotgit add -- "$relpath"

  if dotgit diff --cached --quiet; then
    echo
    echo "Nothing staged for:"
    echo "  $relpath"
    return 0
  fi

  local msg="Add $relpath"
  dotgit commit -m "$msg"
  dotgit push origin main

  echo
  echo "Tracked and pushed:"
  echo "  $relpath"
}

view_log() {
  echo
  if [[ -f "$LOG_FILE" ]]; then
    tail -n 100 "$LOG_FILE"
  else
    echo "No hygiene log found yet:"
    echo "  $LOG_FILE"
  fi
}

show_paths() {
  echo
  echo "Hygiene script : $HYGIENE_SCRIPT"
  echo "Hygiene log    : $LOG_FILE"
  echo "LaunchAgent    : $PLIST_PATH"
  echo "Dotfiles repo  : $DOTGIT_DIR"
}

menu() {
  clear
  echo "=============================================="
  echo "  Shane Dotfiles Hygiene Menu"
  echo "=============================================="
  echo "  1) Run hygiene audit now"
  echo "  2) Run hygiene commit now"
  echo "  3) View hygiene log (last 100 lines)"
  echo "  4) Install weekly schedule (Monday 10:00)"
  echo "  5) Remove weekly schedule"
  echo "  6) Check schedule status"
  echo "  7) Show key paths"
  echo "  8) Track a new managed file"
  echo "  q) Quit"
  echo "=============================================="
}

main() {
  while true; do
    menu
    read -r -p "Choose an option: " choice

    case "$choice" in
      1) run_audit; pause ;;
      2) run_commit; pause ;;
      3) view_log; pause ;;
      4) install_schedule; pause ;;
      5) uninstall_schedule; pause ;;
      6) show_schedule_status; pause ;;
      7) show_paths; pause ;;
      8) track_new_file; pause ;;
      q|Q) exit 0 ;;
      *) echo; echo "Invalid option."; pause ;;
    esac
  done
}

main "$@"