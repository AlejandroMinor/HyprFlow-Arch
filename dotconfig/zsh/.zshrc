export PATH="$HOME/.local/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnoster"

plugins=(git sudo copypath fzf)

source $ZSH/oh-my-zsh.sh

# fzf-tab
source /usr/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh

zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --color=always --style=numbers --line-range=:500 $realpath 2>/dev/null || ls --color $realpath'
zstyle ':fzf-tab:*' fzf-flags --height=60% --layout=reverse --border

# zoxide
eval "$(zoxide init zsh)"

# zsh-autosuggestions
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

# gpg: passphrase in a window when there is a display, in the terminal otherwise
export GPG_TTY=$(tty)
if [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]]; then
    export PINENTRY_USER_DATA=gui
else
    export PINENTRY_USER_DATA=tty
    gpg-connect-agent updatestartuptty /bye >/dev/null
fi

# zsh-syntax-highlighting (always last)
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# fastfetch with random ascii art on every new terminal
~/.local/lib/hyprflow/fastfetch-random.sh
