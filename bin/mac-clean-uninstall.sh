#!/bin/bash
#
# mac-clean-uninstall.sh
# Safely and cleanly uninstall a macOS app with optional Dry Run, Logging, and NeoVim terminal integration.
# Author: Shane Dowley (via Charlie)
#

# ---------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------
LOG_DIR="$HOME/.local/share/mac-clean-uninstall"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/uninstall_$(date +"%Y-%m-%d_%H-%M-%S").log"

# Color support (auto-disabled if output not a TTY or Neovim terminal)
if [ -t 1 ] || [[ $NVIM_LISTEN_ADDRESS ]]; then
  RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; CYAN="\033[36m"; RESET="\033[0m"
else
  RED=""; GREEN=""; YELLOW=""; CYAN=""; RESET=""
fi

log() {
  echo -e "${CYAN}[$(date +"%H:%M:%S")]${RESET} $1" | tee -a "$LOG_FILE"
}

separator() {
  log "--------------------------------------------------"
}

separator
log "🧹  macOS App Cleaner - Uninstaller Utility"
separator

read -rp "Enter the app name (e.g. Pages, Slack, Xcode): " APPNAME
if [[ -z "$APPNAME" ]]; then
  log "${RED}❌  No app name entered. Exiting.${RESET}"
  exit 1
fi

APP_BUNDLE="/Applications/${APPNAME}.app"
USER_APP_BUNDLE="$HOME/Applications/${APPNAME}.app"

declare -a PATHS=(
  "$HOME/Library/Application Support/${APPNAME}"
  "$HOME/Library/Application Support/com.apple.iWork.${APPNAME}"
  "$HOME/Library/Containers/${APPNAME}"
  "$HOME/Library/Containers/com.apple.iWork.${APPNAME}"
  "$HOME/Library/Preferences/${APPNAME}.plist"
  "$HOME/Library/Preferences/com.apple.iWork.${APPNAME}.plist"
  "$HOME/Library/Saved Application State/${APPNAME}.savedState"
  "$HOME/Library/Saved Application State/com.apple.iWork.${APPNAME}.savedState"
  "$HOME/Library/Caches/${APPNAME}"
  "$HOME/Library/Caches/com.apple.iWork.${APPNAME}"
)

# ---------------------------------------------------------------------
# Protected Apps Lock (system-critical apps that cannot be removed)
# ---------------------------------------------------------------------
declare -a PROTECTED_APPS=(
  "Finder"
  "Safari"
  "System Settings"
  "System Preferences"
  "Mail"
  "Messages"
  "Calendar"
  "Contacts"
  "FaceTime"
  "App Store"
  "Music"
  "Photos"
  "Preview"
  "Terminal"
  "Activity Monitor"
  "Notes"
  "Reminders"
  "Maps"
  "News"
  "Weather"
  "Podcasts"
  "TV"
)

# Check if the entered app matches any protected app
# Convert both to lowercase safely using tr
APPNAME_LC=$(echo "$APPNAME" | tr '[:upper:]' '[:lower:]')

for protected in "${PROTECTED_APPS[@]}"; do
  protected_lc=$(echo "$protected" | tr '[:upper:]' '[:lower:]')
  if [[ "$APPNAME_LC" == "$protected_lc" ]]; then
    log "${RED}🚫  '$APPNAME' is a protected macOS system app and cannot be removed.${RESET}"
    log "💡  Aborting for safety."
    exit 1
  fi
done

log ""
log "🔍 Searching for application bundles..."
[[ -d "$APP_BUNDLE" ]] && log "➡️  Found system app: $APP_BUNDLE"
[[ -d "$USER_APP_BUNDLE" ]] && log "➡️  Found user app: $USER_APP_BUNDLE"

log ""
read -rp "Enable Dry Run (show what would be deleted)? (y/N): " DRYRUN
if [[ "$DRYRUN" =~ ^[Yy]$ ]]; then
  DRYRUN=true
  log "🔎  Dry Run mode enabled (no deletions)."
else
  DRYRUN=false
fi

log ""
read -rp "Proceed with uninstalling \"$APPNAME\"? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  log "${YELLOW}❎  Cancelled.${RESET}"
  exit 0
fi

# ---------------------------------------------------------------------
# Delete or Preview
# ---------------------------------------------------------------------
delete_or_preview() {
  local path="$1"
  if [[ -e "$path" ]]; then
    if [[ "$DRYRUN" == true ]]; then
      log "🧾  Would remove: $path"
    else
      log "🧽  Removing: $path"
      rm -rf "$path"
      echo "$(date +"%H:%M:%S") | Removed: $path" >> "$LOG_FILE"
    fi
  fi
}

log ""
log "🗑️  Processing app bundles..."
delete_or_preview "$APP_BUNDLE"
delete_or_preview "$USER_APP_BUNDLE"

log ""
log "🧩  Processing Library support files..."
for path in "${PATHS[@]}"; do
  delete_or_preview "$path"
done

# ---------------------------------------------------------------------
# Final check
# ---------------------------------------------------------------------
log ""
log "🧹  Checking for remaining traces..."
mdfind "kMDItemDisplayName == '$APPNAME'" | grep -i "$APPNAME" | tee -a "$LOG_FILE"

log ""
if [[ "$DRYRUN" == true ]]; then
  log "✅  Dry Run complete. No files were deleted."
else
  log "✅  $APPNAME uninstallation complete."
fi

log "🗒️  Log saved to: $LOG_FILE"
log "💡  Tip: Restart your Mac if the app used background daemons."
separator

# ---------------------------------------------------------------------
# NeoVim integration
# ---------------------------------------------------------------------
if [[ $NVIM_LISTEN_ADDRESS ]]; then
  log "📘 Detected NeoVim terminal session."
  log "You can now open the log inside Neovim with:"
  log ":e $LOG_FILE"
fi
