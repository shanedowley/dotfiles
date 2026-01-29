#!/bin/bash

AEROSPACE_BIN="$(command -v aerospace)"
FOCUSED="$($AEROSPACE_BIN list-workspaces --focused 2>/dev/null | tr -d '\n')"

# Item name is like: aerospace_ws.1, aerospace_ws.2, etc
SID="${NAME#*.}"

if [ "$SID" = "$FOCUSED" ]; then
  sketchybar --set "$NAME" background.color=0xff81a1c1 icon.color=0xff2e3440
else
  sketchybar --set "$NAME" background.color=0x40ffffff icon.color=0xffffffff
fi
