#!/usr/bin/env zsh

# Simple Zsh Game Launcher (exit after launching a game)

# 1) Game names for display
game_names=(
  "Doom"
  "Dead Cells"
  "Oolite"
  "Super Mario 64"
  "Tetris"
  "To the Moon"
)

# 2) Matching commands to launch each game (same index as game_names)
game_cmds=(
  "${HOME}/bin/doom-launcher.sh"
  'open -a "/Applications/Dead Cells/deadcells"'
  'open -a "/Applications/Oolite.app/Contents/MacOS/Oolite"'
  "/Users/shane/sm64ex/build/us_pc/sm64.us.f3dex2e --fullscreen --widescreen"
  "/opt/homebrew/bin/tetris"
  'open -a "/Applications/To The Moon.app/Contents/MacOS/mkxp"'
)

while true; do
 clear 
  echo
  echo "===== Game Launcher ====="
  for i in {1..${#game_names[@]}}; do
    echo "  $i) ${game_names[$i]}"
  done
  echo "  q) Quit"
  echo

  read "choice?Select a game (1-${#game_names[@]} or q): "

  if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
    echo "Goodbye."
    break
  fi

  # Validate numeric choice
  if ! [[ "$choice" == <-> ]] || (( choice < 1 || choice > ${#game_names[@]} )); then
    echo "Invalid choice: $choice"
    continue
  fi

  idx=$choice
  name=${game_names[$idx]}
  cmd=${game_cmds[$idx]}

  echo "Launching: $name"
  echo

  # Run the game in the foreground
  eval "$cmd"

  # Leave the launcher after the game exits
  break
done

