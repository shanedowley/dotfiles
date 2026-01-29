
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
export DOCUMENTS="$HOME/iCloud/Documents"
export DOWNLOADS="$HOME/Downloads"
export WORK="$HOME/iCloud/Documents/Work"
export ICLOUD="$HOME/iCloud"
export GOOGLE="$HOME/Library/CloudStorage/GoogleDrive-shane@betterfasterfurther.com/My Drive"
export CODING="$HOME/Documents/Coding"
export NEOVIM="$HOME/.config/nvim"

# Secrets (NOT committed)
[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"

# Path to dotfiles
export DOTFILES="$HOME/dotfiles"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=4000
SAVEHIST=2000

# Make history more usable
setopt HIST_IGNORE_ALL_DUPS   # skip duplicate commands
setopt HIST_SAVE_NO_DUPS      # don't save duplicates to file
setopt HIST_REDUCE_BLANKS     # trim extraneous spaces
setopt HIST_VERIFY            # confirm before executing recalled history
setopt EXTENDED_HISTORY       # include timestamps


# ---- iterm2 Set Up ----
# Set iterm2's tab title and cursor
function set_iterm_title_and_cursor() {
  # Set iterm2's title to "user: /full/path"
  echo -ne "\033]0;${USER}: ${PWD}\007"

  # Set iterm2's cursor to underline style on every prompt
  echo -ne "\e[4 q"
}
precmd_functions+=(set_iterm_title_and_cursor)


# ---- Aliases Set Up ----

# Quality of life items
alias la='ls -la'
alias ds='dotsync'
alias coding='cd "$CODING" && pwd' 
alias desktop='cd "$DESKTOP" && pwd' 
alias docs='cd "$DOCUMENTS" && pwd' 
alias downloads='cd "$DOWNLOADS" && pwd' 
alias google='cd "$GOOGLE" && pwd'
alias icloud='cd "$ICLOUD" && pwd'
alias reading='cd "$READING" && pwd'
alias work='cd "$WORK" && pwd'
alias reload='source ~/.zshrc >/dev/null && echo "🔁 zsh config reloaded."'
alias rmapp='$HOME/bin/mac-clean-uninstall.sh'

# Avoid accidental deletions / overwrites
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# Prevent rm -f from asking for confirmation on things like `rm -f *.bak`.
setopt rm_star_silent

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

# Run Speccy emulators, zxsp or ZEsarUX
alias zxsp='open -a zxsp'
alias zesarux='/Applications/ZEsarUX.app/Contents/MacOS/zesarux'

# Gaming :) 
alias doom='$HOME/bin/doom-launcher'
alias deadcells='/Applications/"Dead Cells"/deadcells &'
alias oolite='/Applications/Oolite.app/Contents/MacOS/Oolite &'

# Start Jekyll and Tailwind servers for Web and CSS dev. From project root: 
alias webdev="npm run dev"


# Use Homebrew's clang to build and macOS SDK to link
alias clangsys='clang -target arm64-apple-macos -isysroot $(xcrun --show-sdk-path)'


# --- Tmux setup ---
if command -v tmux >/dev/null 2>&1 && [ -z "$TMUX" ] && [ -z "$NO_TMUX" ]; then
  tmux new-session -A -s main
fi


# ---- My Dotfiles Set Up ----
# Git repo for my dotfiles:
alias dotgit='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
export GIT_SSH_COMMAND="/usr/bin/ssh"
alias gs='git status'


# dotsync: commits bare repo ~/.dotfiles (tracks selected $HOME paths)
function dotsync {
  (
    set -euo pipefail

    cd "$HOME" || { echo "dotsync: unable to access $HOME"; exit 1; }

    # Always use the bare repo
    local dotgit_cmd=(/usr/bin/git --git-dir="$HOME/.dotfiles" --work-tree="$HOME")

    # Only these paths are ever staged by dotsync (keep this list small and intentional)
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

    # Global excludes (today: only universally-safe junk)
    # (Tomorrow we’ll “lock down ignores” for coc/neovim caches properly.)
    local -a excludes=(
      ':(exclude)**/.DS_Store'
      ':(exclude)**/__MACOSX/**'
      ':(exclude)**/._*'
      ':(exclude)**/*~'
      ':(exclude)**/.Trash/**'
    )

    # Build add list, skipping missing paths (no failures, just warnings)
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

    # Stage only intended files
    "${dotgit_cmd[@]}" add -- "${add_paths[@]}" "${excludes[@]}"

    # Nothing staged? Exit quietly.
    if "${dotgit_cmd[@]}" diff --cached --quiet; then
      echo "dotsync: nothing to commit"
      exit 0
    fi

    # Tight summary: what will be committed
    echo "dotsync: staged changes:"
    "${dotgit_cmd[@]}" diff --cached --name-status

    # Commit + push
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
autoload -Uz colors && colors      # enable color support
setopt PROMPT_SUBST               # allow command substitution in prompt

# Left prompt: current folder + git branch
PS1=$'\n%F{blue}───%f\n[%F{$([ $? -eq 0 ] && echo cyan || echo red)}%2~%f%F{yellow}$(__git_ps1 " (%s)")%f]$( [ $EUID -eq 0 ] && echo "#" || echo "$" ) '


# Optional: right prompt (show time)
RPROMPT='%F{magenta}%*%f'


# --- Dev env variables Set Up ---
# LLVM + Ruby libs/includes (merged instead of overwritten)
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib -L/opt/homebrew/opt/ruby/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include -I/opt/homebrew/opt/ruby/include"

eval "$(rbenv init - zsh)"


# ---- Starship Set Up ----
eval "$(starship init zsh)"




