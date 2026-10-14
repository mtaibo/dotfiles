# Aliases
alias l='eza -lhH --icons --group-directories-first --git --color-scale=size'
alias ls='eza --icons --group-directories-first --color-scale=size'
alias ll='eza -lghHa --icons --group-directories-first --color-scale=size'
alias la='eza -a --icons --group-directories-first --color-scale=size'
alias lt='eza --tree --level=4 --ignore-glob="venv" --icons --color-scale=size'
alias cat='bat'

# Add Xcode SDK man pages (e.g. system call manuals)
export MANPATH="$(xcrun --show-sdk-path)/usr/share/man:$MANPATH"
