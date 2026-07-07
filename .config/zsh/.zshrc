export EDITOR="nvim"
export TERM="xterm-256color"
export HISTSIZE=2000
export SAVEHIST=$HISTSIZE
export HISTFILE="${XDG_CONFIG_HOME}/zsh/history"

YELLOW="$(tput setaf 11)"
RESET="$(tput sgr0)"

export PS1="%{$YELLOW%}%1~ $ %{$RESET%}"

alias zshrc="$EDITOR ${ZDOTDIR}/.zshrc"
alias reload="source ${ZDOTDIR}/.zshrc"
alias pacman="$HOME/lazy-pacman"
alias gbye="pkill awesome"
alias vim="nvim"
alias xinitrc="nvim ${XDG_CONFIG_HOME}/X11/Xinitrc"

function prepend_path() {
  if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
    PATH="$1:$PATH"
  fi
}

prepend_path "$HOME/.local/bin"
