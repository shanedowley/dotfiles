
export LANG="en_GB.UTF-8"
export LC_ALL="en_GB.UTF-8"

source ~/bin/codex-aliases.sh
source ~/.git-prompt.sh
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

# Path to dotfiles
export DOTFILES=$HOME/dotfiles

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

# ---- iTerm2 Theme Control ----
# Usage: setiterm_theme "gruvbox-dark" or "tokyonight_night"
setiterm_theme() {
  local preset="$1"
  if [[ -z "$preset" ]]; then
    echo "Usage: setiterm_theme \"Preset Name\"" >&2
    return 1
  fi

  # AppleScript to apply a preset or fallback to manual color set
  osascript <<EOF
  tell application "iTerm2"
    try
      tell current window
        tell current session
          set color preset to "$preset"
        end tell
      end tell
    on error
      display notification "Preset '$preset' not found or unsupported in this version" with title "iTerm2 Theme Switch"
    end try
  end tell
EOF
}

# iterm2 color schemes
alias colour-catppuccin='setiterm_theme "catppuccin-mocha"'
alias colour-django-smooth='setiterm_theme "DjangoSmooth"'
alias colour-doom-peacock='setiterm_theme "Doom Peacock"'
alias colour-gruvbox='setiterm_theme "gruvbox-dark"'
alias colour-kanagawa='setiterm_theme "kanagawa"'
alias colour-rose-pine='setiterm_theme "rose-pine"'
alias colour-tokyonight='setiterm_theme "tokyonight_night"'


# ---- Aliases Set Up ----

# Quality of life items
alias la='ls -la'
alias coding='cd $CODING/ && echo $PWD' 
alias desktop='cd $DESKTOP/ && echo $PWD' 
alias docs='cd $DOCUMENTS/ && echo $PWD' 
alias downloads='cd $DOWNLOADS/ && echo $PWD' 
alias google='cd $GOOGLE/ && echo $PWD'
alias icloud='cd $ICLOUD/ && echo $PWD'
alias reading='cd $READING/ && echo $PWD'
alias work='cd $WORK/ && echo $PWD'
alias rust-book='safarireader "/Users/shane/.rustup/toolchains/stable-aarch64-apple-darwin/share/doc/rust/html/book/title-page.html"'
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
# Invoke Neovide silently and in the background passing a filename arg
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

# Load Codex aliases if available
if [ -f "$HOME/codex-aliases.sh" ]; then
  source "$HOME/codex-aliases.sh"
fi

# Use Homebrew's clang to build and macOS SDK to link
alias clangsys='clang -target arm64-apple-macos -isysroot $(xcrun --show-sdk-path)'

# --- Tmux setup ---
if command -v tmux >/dev/null 2>&1 && [ -z "$TMUX" ]; then
  tmux new-session -A -s main
fi

# ---- My Dotfiles Set Up ----
# Git repo for my dotfiles:
alias dotgit='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
export GIT_SSH_COMMAND="/usr/bin/ssh"
alias gs='git status'
function sync {
  (
    cd "$HOME/dotfiles" || {
      echo "sync: unable to access $HOME/dotfiles"
      exit 1
    }

    git add -A

    if git diff --cached --quiet; then
      echo "sync: nothing staged"
      exit 0
    fi

    git commit -m "Update dotfiles ($(date +%Y-%m-%d))" && git push origin main
  )
}

function dotsync {
  (
    cd "$HOME" || {
      echo "dotsync: unable to access $HOME"
      exit 1
    }

    local -a tracked_paths=(
      ".config"
      ".tmux.conf"
      ".zshrc"
      "bin"
      "dotfiles"
      "Documents/coding"
    )

    local -a add_paths=()
    for path in "${tracked_paths[@]}"; do
      if [ -e "$path" ]; then
        add_paths+=("$path")
      else
        echo "dotsync: warning: $HOME/$path not found, skipping" >&2
      fi
    done

    if [ ${#add_paths[@]} -eq 0 ]; then
      echo "dotsync: no tracked paths available"
      exit 0
    fi

    # Stage configured paths, excluding macOS temp files that start with "~"
    dotgit add -A -- "${add_paths[@]}" ':(exclude)**/~*' ':(exclude)~*'

    if dotgit diff --cached --quiet; then
      echo "dotsync: nothing staged"
      exit 0
    fi

    dotgit commit -m "Update home dotfiles ($(/bin/date +%Y-%m-%d))" && dotgit push origin main
  )
}

# Git setup for zsh
ZSH_DISABLE_COMPFIX=true
autoload -Uz vcs_info
autoload -Uz compinit && compinit
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )


# --- Prompt setup ---
autoload -Uz colors && colors      # enable color support
setopt PROMPT_SUBST               # allow command substitution in prompt

# Left prompt: current folder + git branch
PS1=$'\n%F{blue}───%f\n[%F{$([ $? -eq 0 ] && echo cyan || echo red)}%2~%f%F{yellow}$(git rev-parse --abbrev-ref HEAD >/dev/null 2>&1 && __git_ps1 " (%s)" || echo "")%f]$( [ $EUID -eq 0 ] && echo "#" || echo "$" ) '

# Optional: right prompt (show time)
RPROMPT='%F{magenta}%*%f'

# Format git branch name via git-prompt.sh
zstyle ':vcs_info:git:*' formats '%b'


# --- Dev env variables Set Up ---
# LLVM + Ruby libs/includes (merged instead of overwritten)
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib -L/opt/homebrew/opt/ruby/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include -I/opt/homebrew/opt/ruby/include"

eval "$(rbenv init - zsh)"
export PATH="/opt/homebrew/opt/rustup/bin:$PATH"


# ---- Starship Set Up ----
eval "$(starship init zsh)"
