# Aliases
alias l='eza -lhH --icons --group-directories-first --git'
alias ls='eza --icons --group-directories-first'
alias ll='eza -lghHa --icons --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias lt='eza --tree --level=4 --ignore-glob="venv" --icons'
alias cat='bat'
alias gl='git log --oneline --graph --all'

# Add Xcode SDK man pages (e.g. system call manuals)
if command -v xcrun &>/dev/null; then
  export MANPATH="$(xcrun --show-sdk-path)/usr/share/man:$MANPATH"
fi
