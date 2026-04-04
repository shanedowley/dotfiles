#!/bin/bash

STATE_FILE="$HOME/.config/sketchybar/timer_state"
ITEM_NAME="timer"
SKETCHYBAR_BIN="$(command -v sketchybar)"

set_label() {
  "$SKETCHYBAR_BIN" --set "$ITEM_NAME" label="$1"
}

prompt_start() {
  local mins secs total

  read -r -p "Minutes: " mins
  read -r -p "Seconds: " secs

  mins="${mins:-0}"
  secs="${secs:-0}"

  if ! [[ "$mins" =~ ^[0-9]+$ ]]; then
    echo "Invalid minutes value."
    exit 1
  fi

  if ! [[ "$secs" =~ ^[0-9]+$ ]]; then
    echo "Invalid seconds value."
    exit 1
  fi

  total=$(( mins * 60 + secs ))

  if [ "$total" -le 0 ]; then
    echo "Timer must be greater than 0 seconds."
    exit 1
  fi

  start_timer "$total"
}

start_timer() {
  local seconds="$1"
  local end

  end=$(( $(date +%s) + seconds ))
  echo "$end" > "$STATE_FILE"
  "$0" status
}

case "${1:-prompt}" in
  prompt)
    prompt_start
    ;;

  start)
    seconds="${2:-0}"
    if ! [[ "$seconds" =~ ^[0-9]+$ ]] || [ "$seconds" -le 0 ]; then
      echo "Usage: $0 start <seconds>"
      exit 1
    fi
    start_timer "$seconds"
    ;;

  stop)
    rm -f "$STATE_FILE"
    set_label "Timer: --:--"
    ;;

  status)
    if [ ! -f "$STATE_FILE" ]; then
      set_label "Timer: --:--"
      exit 0
    fi

    end="$(cat "$STATE_FILE" 2>/dev/null)"

    if ! [[ "$end" =~ ^[0-9]+$ ]]; then
      set_label "Timer: ERR"
      exit 1
    fi

    now=$(date +%s)
    remaining=$(( end - now ))

    if [ "$remaining" -le 0 ]; then
      set_label "Timer: DONE"
    else
      mins=$(( remaining / 60 ))
      secs=$(( remaining % 60 ))
      label=$(printf "%02d:%02d" "$mins" "$secs")
      set_label "Timer: $label"
    fi
    ;;

  *)
    echo "Usage: $0 [prompt|start <seconds>|stop|status]"
    exit 1
    ;;
esac