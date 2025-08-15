#!/usr/bin/env bash
# vc: atajo para montar/desmontar con VeraCrypt CLI (modo texto)
# Uso:
#   vc mount  <container.hc> <mountpoint>
#   vc umount <mountpoint>
#   vc list
set -euo pipefail

cmd="${1:-}"; shift || true

case "${cmd}" in
  mount)
    cont="${1:?uso: vc mount <container.hc> <mountpoint>}"; mnt="${2:?uso: vc mount <container.hc> <mountpoint>}"
    mkdir -p -- "$mnt"
    chmod 0700 "$mnt"
    exec veracrypt --text --mount "$cont" "$mnt"          # pedirá pass y PIM aquí
    ;;
  umount|unmount)
    mnt="${1:?uso: vc umount <mountpoint>}"
    exec veracrypt -d "$mnt"
    ;;
  list)
    exec veracrypt -l
    ;;
  *)
    echo "uso: vc {mount|umount|list} ..."; exit 1 ;;
esac
