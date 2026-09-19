export EDITOR="nvim"
export TERM="xterm-256color"
export HISTSIZE=2000
export SHELL="/bin/zsh"
export SAVEHIST=$HISTSIZE
export HISTFILE="${XDG_CONFIG_HOME}/zsh/history"
export ZSH_CUSTOM="$HOME/.config/oh-my-zsh/custom"
export ZSH_THEME="skill"
export GEM_HOME="$HOME/.local/share/gem"
export GEM_PATH="$HOME/.local/share/gem"

YELLOW="%{$(tput setaf 11)%}"
RESET="%{$(tput sgr0)%}"

export PS1="%{$YELLOW%}%1~ $ %{$RESET%}"

sv() {
    case "$1" in
        +*) pactl set-sink-volume @DEFAULT_SINK@ "${1#?}%+" ;;
        -*) pactl set-sink-volume @DEFAULT_SINK@ "${1#?}%-" ;;
        *)  pactl set-sink-volume @DEFAULT_SINK@ "$1%" ;;
    esac
}

function prepend_path() {
  if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
    PATH="$1:$PATH"
  fi
}

prepend_path "$HOME/.local/bin"
prepend_path "$HOME/.local/share/gem/ruby/3.4.0/bin"
prepend_path "$HOME/.local/share/gem/ruby/3.4.0/bin"

export ZSH="$HOME/.config/oh-my-zsh"

plugins=( git )

[[ -f "$ZSH/oh-my-zsh.sh" ]] && . "$ZSH/oh-my-zsh.sh"


unalias l
[[ -f "${XDG_CONFIG_HOME}/aliasrc" ]] && . "${XDG_CONFIG_HOME}/aliasrc"
[[ -f "${XDG_CONFIG_HOME}/bookmarkrc" ]] && . "${XDG_CONFIG_HOME}/bookmarkrc"