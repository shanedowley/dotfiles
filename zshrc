PROMPT='%2~ $'

source ~/.git-prompt.sh
if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]]; then
    export TERMCS="dark"
else
    export TERMCS="light"
fi

export PATH="/Applications/MacVim.app/Contents/bin:~/bin:$PATH"
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export EDITOR="/Applications/MacVim.app/Contents/bin/vim"
export TMP="/Users/shane/tmp"
export REPOS="/Users/shane/repos"
export READING="/Users/shane/Desktop/reading, writing and study"
export DOCUMENTS="/Users/shane/iCloud/Documents"
export DOWNLOADS="/Users/shane/Downloads"
export WORK="/Users/shane/iCloud/Documents/Work"
export ICLOUD="/Users/shane/iCloud"
export GOOGLE="/Users/shane/Library/CloudStorage/GoogleDrive-shane@betterfasterfurther.com/My Drive"
export CODING="/Users/shane/Documents/Coding"
export LDFLAGS="-L/opt/homebrew/opt/ruby/lib"
export CPPFLAGS="-I/opt/homebrew/opt/ruby/include"
export DPROJECTS="/Users/shane/Documents/Coding/dlang/projects"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=4000
SAVEHIST=2000

alias la='ls -la'

# To invoke Neovim from the command line
alias vim='/opt/homebrew/bin/nvim'
alias vi='/opt/homebrew/bin/nvim'

# Git repo for my dotfiles:
alias dotgit='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# Avoid accidental deletions
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# Shutdown and Reboot 
alias shutdown='sudo shutdown +5s "System shutting down ..."'
alias reboot='sudo shutdown -r +5s "System rebooting ..."'

# alias s-nail to mailx for convenience
alias mailx="s-nail"

# alias run Jekyll server from within your Jekyll project directory
alias serve-j="~/my-jekyll-site/serve-j.zsh"

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

eval "$(rbenv init - zsh)"
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
