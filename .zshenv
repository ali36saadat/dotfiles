export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

ZDOTDIR="${XDG_CONFIG_HOME}/zsh/"
export XINITRC="${XDG_CONFIG_HOME}/X11/Xinitrc"

export CARGO_HOME="${XDG_DATA_HOME}/cargo"

# Proto
if [[ -f "${XDG_DATA_HOME}/cargo/env" ]]; then
  . "${XDG_DATA_HOME}/cargo/env"
fi
