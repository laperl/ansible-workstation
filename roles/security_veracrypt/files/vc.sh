#!/usr/bin/env bash
# Wrapper seguro para VeraCrypt (CLI, sin exponer contraseña en argv/env).
set -euo pipefail

usage(){ echo "uso: vc {mount|umount|list} <container> <mountpoint> [pim]"; }

cmd="${1:-}"; cont="${2:-}"; mnt="${3:-}"; pim="${4:-}"

case "${cmd:-}" in
  mount)
    [ -n "${cont:-}" ] && [ -n "${mnt:-}" ] || { usage; exit 1; }
    mkdir -p -- "$mnt"
    # Pide pass por el agente de systemd y pásala por STDIN a veracrypt
    PASS="$(/usr/bin/systemd-ask-password "Passphrase VeraCrypt para ${cont}:")" || exit 1
    printf '%s' "$PASS" | veracrypt --text --non-interactive --stdin \
      ${pim:+--pim="$pim"} --protect-hidden=no "$cont" "$mnt"
    unset PASS
    ;;
  umount|unmount)
    [ -n "${mnt:-}" ] || { usage; exit 1; }
    veracrypt --text -d "$mnt" || true
    ;;
  list)
    veracrypt -l
    ;;
  *)
    usage; exit 1 ;;
esac
