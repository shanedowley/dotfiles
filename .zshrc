export LANG="en_GB.UTF-8"

[ -f "$HOME/bin/codex-aliases.sh" ] && source "$HOME/bin/codex-aliases.sh"
[ -f "$HOME/.git-prompt.sh" ] && source "$HOME/.git-prompt.sh"
typeset -f __git_ps1 >/dev/null 2>&1 || __git_ps1() { :; }

if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]]; then
    export TERMCS="dark"
else
    export TERMCS="light"
fi

export PATH="/opt/homebrew/opt/llvm/bin:/opt/homebrew/opt/ruby/bin:$HOME/.local/share/nvim/mason/bin:$HOME/bin:$PATH"
export EDITOR="/opt/homebrew/bin/nvim"
export TMP="$HOME/tmp"
export READING="$HOME/Desktop/reading, writing and study"
export DESKTOP="$HOME/Desktop"
export APPSUPPORT="$HOME/Library/Application Support/"
export DOCUMENTS="$HOME/iCloud/Documents"
export DOWNLOADS="$HOME/Downloads"
export WORK="$HOME/iCloud/Documents/Work"
export ICLOUD="$HOME/iCloud"
export GOOGLE="$HOME/Library/CloudStorage/GoogleDrive-shane@betterfasterfurther.com/My Drive"
export CODING="$HOME/Documents/Coding"
export NEOVIM="$HOME/.config/nvim"
unset NVIM_LOG_FILE

# Secrets (NOT committed)
[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"

# Path to dotfiles
export DOTFILES="$HOME/.dotfiles"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=4000
SAVEHIST=2000

# Make history more usable
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt EXTENDED_HISTORY
setopt rm_star_silent

# tmux smart session launcher
unalias work 2>/dev/null
unalias play 2>/dev/null

work() {
  tmux new-session -A -s work -c "$WORK"
}

play() {
  tmux new-session -A -s play -c "$HOME"
}

# ---- Aliases Set Up ----
alias la='ls -la'
alias ds='dotsync'
alias coding='cd "$CODING" && pwd'
alias cbc='pbcopy'
alias cbp='pbpaste'
alias desktop='cd "$DESKTOP" && pwd'
alias docs='cd "$DOCUMENTS" && pwd'
alias downloads='cd "$DOWNLOADS" && pwd'
alias google='cd "$GOOGLE" && pwd'
alias icloud='cd "$ICLOUD" && pwd'
alias reading='cd "$READING" && pwd'
alias reload='source ~/.zshrc >/dev/null && echo "🔁 zsh config reloaded."'
alias rmapp='$HOME/bin/mac-clean-uninstall.sh'
alias timer='~/.config/sketchybar/timer.sh'
alias timerstop='~/.config/sketchybar/timer.sh stop'
alias workdir='cd "$WORK" && pwd'

# Avoid accidental deletions / overwrites
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# To invoke Neovim from the command line
alias vim='/opt/homebrew/bin/nvim'
alias vi='/opt/homebrew/bin/nvim'
alias v='/opt/homebrew/bin/nvim'

# 'n' to invoke Neovide silently and in the background passing a filename arg
n() {
  if (( $# == 0 )); then
    neovide . >/dev/null 2>&1 &
  else
    neovide "$@" >/dev/null 2>&1 &
  fi
}

# Shutdown and Reboot
alias shutdown='sudo shutdown -h +5s "System shutting down ..."'
alias reboot='sudo shutdown -r +5s "System rebooting ..."'

# Gaming :)
alias game='$HOME/bin/game-launcher.sh'
alias doom-last='$HOME/bin/doom-launcher --last'
alias sm64config='vim $APPSUPPORT/sm64ex/sm64config.txt'

# Start Jekyll and Tailwind servers for Web and CSS dev. From project root:
alias webdev="npm run dev"

# Use Homebrew's clang to build and macOS SDK to link
alias clangsys='clang -target arm64-apple-macos -isysroot $(xcrun --show-sdk-path)'

# ---- My Dotfiles Set Up ----
alias dotgit='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
export GIT_SSH_COMMAND="/usr/bin/ssh"
alias gs='git status'

# Hygiene options and operations for my set up
alias hygiene='$HOME/bin/hygiene-menu.sh'

# dotsync: commits bare repo ~/.dotfiles (tracks selected $HOME paths)
function dotsync {
  (
    set -euo pipefail

    cd "$HOME" || { echo "dotsync: unable to access $HOME"; exit 1; }

    local dotgit_cmd=(/usr/bin/git --git-dir="$HOME/.dotfiles" --work-tree="$HOME")

    local -a tracked_paths=(
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
    )

local -a excludes=(
  ':(exclude)**/.DS_Store'
  ':(exclude)**/__MACOSX/**'
  ':(exclude)**/._*'
  ':(exclude)**/*~'
  ':(exclude)**/.Trash/**'
  ':(exclude).config/nvim/nvim/**'
  ':(exclude).config/nvim/gem/**'
  ':(exclude).config/sketchybar/timer_state'
  ':(exclude)**/*.bak'
  ':(exclude)**/*.org'
)



    local -a add_paths=()
    local p
    for p in "${tracked_paths[@]}"; do
      if [[ -e "$p" ]]; then
        add_paths+=("$p")
      else
        echo "dotsync: warning: $HOME/$p not found, skipping" >&2
      fi
    done

    if (( ${#add_paths[@]} == 0 )); then
      echo "dotsync: no tracked paths available"
      exit 0
    fi

    "${dotgit_cmd[@]}" add -- "${add_paths[@]}" "${excludes[@]}"

    if "${dotgit_cmd[@]}" diff --cached --quiet; then
      echo "dotsync: nothing to commit"
      exit 0
    fi

    echo "dotsync: staged changes:"
    "${dotgit_cmd[@]}" diff --cached --name-status

    local msg="dotsync ($(date +%Y-%m-%d))"
    "${dotgit_cmd[@]}" commit -m "$msg"
    "${dotgit_cmd[@]}" push origin main

    echo "dotsync: done ✅"
  )
}

# Git setup for zsh
ZSH_DISABLE_COMPFIX=true
autoload -Uz compinit && compinit -C

# --- Prompt setup ---
autoload -Uz colors && colors
setopt PROMPT_SUBST

PS1=$'\n%F{blue}───%f\n[%F{$([ $? -eq 0 ] && echo cyan || echo red)}%2~%f%F{yellow}$(__git_ps1 " (%s)")%f]$( [ $EUID -eq 0 ] && echo "#" || echo "$" ) '
RPROMPT='%F{magenta}%*%f'

# --- Dev env variables Set Up ---
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib -L/opt/homebrew/opt/ruby/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include -I/opt/homebrew/opt/ruby/include"

eval "$(rbenv init - zsh)"

# --- Cursor setup ---
bindkey -v

function _set_cursor_beam() {
  printf '\e[6 q'
}

function _set_cursor_block() {
  printf '\e[2 q'
}

function zle-keymap-select {
  if [[ $KEYMAP == vicmd ]]; then
    _set_cursor_block
  else
    _set_cursor_beam
  fi
}
zle -N zle-keymap-select

function zle-line-init {
  zle -K viins
  _set_cursor_beam
}
zle -N zle-line-init

function zle-line-finish {
  _set_cursor_beam
}
zle -N zle-line-finish


# ---- Starship Set Up ----
eval "$(starship init zsh)"



