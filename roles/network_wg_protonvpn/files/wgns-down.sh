#!/usr/bin/env bash
set -euo pipefail
NS="${1:-}"; [[ -n "${NS}" ]] || { echo "Uso: $0 <instancia>"; exit 2; }
logger -t wg-ns "down[${NS}] (stub): aún no implementado; no realiza cambios de red." "${NS}"
exit 0
