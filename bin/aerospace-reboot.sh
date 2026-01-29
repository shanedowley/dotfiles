#!/usr/bin/env bash
#
# aerospace-reboot.sh
# Cleanly stop and restart AeroSpace, then verify CLI connectivity
# Author: Shane Dowley
#

set -euo pipefail

APP="/Applications/AeroSpace.app"
CLI="$(command -v aerospace || true)"

echo "== AeroSpace reboot =="

# --- Preconditions ----------------------------------------------------
if [[ -z "$CLI" ]]; then
  echo "ERROR: 'aerospace' CLI not found in PATH."
  exit 1
fi

if [[ ! -d "$APP" ]]; then
  echo "ERROR: AeroSpace.app not found at: $APP"
  exit 1
fi

# --- Kill any existing instances -------------------------------------
echo "Stopping AeroSpace (if running)..."
killall AeroSpace 2>/dev/null || true
pkill -f "AeroSpace.app/Contents/MacOS/AeroSpace" 2>/dev/null || true

# --- Confirm nothing is running --------------------------------------
if pgrep -fl AeroSpace >/dev/null; then
  echo "Note: AeroSpace processes still present:"
  pgrep -fl AeroSpace || true
else
  echo "No AeroSpace processes."
fi

# --- Launch -----------------------------------------------------------
echo "Launching AeroSpace..."
open -gj -a "$APP"

# --- Wait for server to become reachable ------------------------------
echo -n "Waiting for server"
for _ in {1..60}; do
  ver_out="$(aerospace --version 2>/dev/null || true)"

  if echo "$ver_out" | grep -q "AeroSpace.app server version:" \
     && ! echo "$ver_out" | grep -q "AeroSpace.app server version: Unknown"; then
    echo
    echo "Server reachable."
    echo "$ver_out"
    echo

    # These should now succeed
    aerospace reload-config
    aerospace list-windows --all || true

    echo "Done."
    exit 0
  fi

  echo -n "."
  sleep 0.2
done

echo
echo "ERROR: AeroSpace server did not become reachable in time."
echo "Last observed version output:"
echo "$ver_out"
exit 2
