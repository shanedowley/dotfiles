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
export APPSUPPORT="$HOME/Library/Application Support"
export DOCUMENTS="$HOME/iCloud/Documents"
export DOWNLOADS="$HOME/Downloads"
export WORK="$HOME/iCloud/Documents/Work"
export ICLOUD="$HOME/iCloud"
export GOOGLE="$HOME/Library/CloudStorage/GoogleDrive-shane@betterfasterfurther.com/My Drive"
export CODING="$HOME/Documents/Coding"
export NEOVIM="$HOME/.config/nvim"

# Secrets (NOT committed)
[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"

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
alias coding='cd "$CODING" && pwd'
alias cbc='pbcopy'
alias cbp='pbpaste'
alias desktop='cd "$DESKTOP" && pwd'
alias docs='cd "$DOCUMENTS" && pwd'
alias downloads='cd "$DOWNLOADS" && pwd'
alias google='cd "$GOOGLE" && pwd'
alias icloud='cd "$ICLOUD" && pwd'
alias reading='cd "$READING" && pwd'
alias reload='source "$HOME/.zshrc" >/dev/null && echo "🔁 zsh config reloaded."'
alias rmapp='$HOME/bin/mac-clean-uninstall.sh'
alias timer="$HOME/.config/sketchybar/timer.sh"
alias timerstop="$HOME/.config/sketchybar/timer.sh stop"

# Avoid accidental deletions / overwrites
alias rm='rm -i'
alias mv='mv -i'

# To invoke Neovim from the command line
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
alias doom-last='$HOME/bin/doom-launcher.sh --last'
alias sm64config='vim "$APPSUPPORT/sm64ex/sm64config.txt"'

# Start Jekyll and Tailwind servers for Web and CSS dev. From project root:
alias webdev="npm run dev"

# Use Homebrew's clang to build and macOS SDK to link
alias clangsys='clang -target arm64-apple-macos -isysroot $(xcrun --show-sdk-path)'

# ---- My Dotfiles Set Up ----
alias dotgit='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
export GIT_SSH_COMMAND="/usr/bin/ssh"

# Hygiene options and operations for my set up
alias hygiene='$HOME/bin/hygiene-menu.sh'

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



