PROMPT='%2~ $'

source ~/codex-aliases.sh
source ~/.git-prompt.sh
if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]]; then
    export TERMCS="dark"
else
    export TERMCS="light"
fi

export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="$HOME/bin:$PATH"
export EDITOR="/opt/homebrew/bin/nvim"
export TMP="$HOME/tmp"
export READING="$HOME/Desktop/reading, writing and study"
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

# ---- iTerm2 Theme Control ----
# Usage: setiterm_theme "Gruvbox Dark" or "Tokyonight Storm"
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

# Aliases 
alias la='ls -la'
alias coding='cd $CODING/ && echo $PWD'

# To invoke Neovim from the command line
alias vim='/opt/homebrew/bin/nvim'
alias vi='/opt/homebrew/bin/nvim'
alias v='/opt/homebrew/bin/nvim'

# Git repo for my dotfiles:
alias dotgit='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias gs='git status'
alias sync='cd ~/dotfiles && git add -A && git commit -m "Update dotfiles ($(date +%Y-%m-%d))" && git push origin main && cd -'

# Avoid accidental deletions
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# Shutdown and Reboot 
alias shutdown='sudo shutdown +5s "System shutting down ..."'
alias reboot='sudo shutdown -r +5s "System rebooting ..."'

# alias launch Docker daemon via MacOS app, silently
alias docker="open -g -a Docker" 

# alias run Speccy emulator, zxsp
alias zxsp="open -a zxsp"
# alias run Speccy emulator, zeusarux
alias zesarux="/Applications/ZEsarUX.app/Contents/MacOS/zesarux"

# alias iterm color schemes
alias colour-catppuccin="setiterm_theme "catppuccin-mocha""
alias colour-django-smooth="setiterm_theme "DjangoSmooth""
alias colour-gruvbox="setiterm_theme "gruvbox-dark""
alias colour-kanagawa="setiterm_theme "kanagawa""
alias colour-rose-pine="setiterm_theme "rose-pine""
alias colour-toykonight="setiterm_theme "toykonight_night""

# alias to start Jekyll and Tailwind servers for Web and CSS dev. From project root: 
alias webdev="npm run dev"

# Prevent rm -f from asking for confirmation on things like `rm -f *.bak`.
setopt rm_star_silent

# Git setup for zsh
autoload -Uz vcs_info
autoload -Uz compinit && compinit
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
setopt PROMPT_SUBST ; PS1='[%n@%m %c$(__git_ps1 " (%s)")]\$ '
RPROMPT='${vcs_info_msg_0_}'
zstyle ':vcs_info:git:*' formats '%b'

# Development env variables

# LLVM + Ruby libs/includes (merged instead of overwritten)
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib -L/opt/homebrew/opt/ruby/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include -I/opt/homebrew/opt/ruby/include"

# PATHs
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"

# Custom project dir
export DPROJECTS="$HOME/Documents/Coding/dlang/projects"

# Load Codex aliases if available
if [ -f "$HOME/codex-aliases.sh" ]; then
  source "$HOME/codex-aliases.sh"
fi

eval "$(rbenv init - zsh)"
