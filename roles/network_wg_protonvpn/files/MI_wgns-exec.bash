#!/usr/bin/env bash
# MI_wgns-exec.bash — wrapper mínimo para 1 app dentro de un netns
# Uso: sudo MI_wgns-exec.bash <ns> -- <cmd> [args...]
set -euo pipefail
NS="${1:-}"; shift || { echo "Uso: $0 <ns> -- <cmd> [args...]" >&2; exit 2; }
[[ "${1:-}" == "--" ]] || { echo "Falta separador --" >&2; exit 2; }
shift
USER_TO_RUN="${SUDO_USER:-$(id -un)}"
# Ejecuta el comando dentro del netns como usuario normal
exec ip netns exec "$NS" sudo -u "$USER_TO_RUN" -- "$@"
