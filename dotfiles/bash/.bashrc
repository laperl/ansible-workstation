# ~/.bashrc - básico, seguro y portable
export EDITOR="${EDITOR:-vim}"
export PATH="$PATH:$HOME/.local/bin"

# Alias útiles
if [ -f "$HOME/.bash_aliases" ]; then
  . "$HOME/.bash_aliases"
fi
