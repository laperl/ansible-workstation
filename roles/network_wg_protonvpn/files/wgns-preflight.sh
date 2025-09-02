#!/usr/bin/env bash
# Preflight para instancia %i. Se ejecuta como ExecStartPre=.
# - Carga /etc/wg-ns/%i.env (EnvironmentFile ya inyecta VAR=VAL; aquí lo re-leemos si se llama a mano).
# - Valida conectividad en host, autodetecta WAN_IF si vacío y detecta solapes de SUBNET_P2P.
# - Registra en journal con `logger -t wg-ns`.
# Docs: ip-netns(8), network_namespaces(7), logger(1), systemd-journald(8)
set -euo pipefail

NS="${1:-}"
if [[ -z "${NS}" ]]; then
  echo "Uso: $0 <instancia>" >&2
  exit 2
fi

ENV_FILE="/etc/wg-ns/${NS}.env"
if [[ -r "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  . "${ENV_FILE}"
fi

log()  { logger -t wg-ns "preflight[${NS}] $*"; }
fail() { logger -t wg-ns "preflight[${NS}] ERROR: $*"; echo "ERROR: $*" >&2; exit 1; }

# 1) Validaciones mínimas de variables críticas
: "${SUBNET_P2P:?SUBNET_P2P no definido en ${ENV_FILE}}"
: "${HOST_IP:?HOST_IP no definido en ${ENV_FILE}}"
: "${NS_IP:?NS_IP no definido en ${ENV_FILE}}"

# 2) Comprobación de ruta a Internet (host)
if ! ip route get 1.1.1.1 >/dev/null 2>&1; then
  fail "No hay ruta a 1.1.1.1 desde el host (sin conectividad general)."
fi

# 3) Detectar WAN_IF si está vacío
if [[ -z "${WAN_IF:-}" ]]; then
  WAN_IF="$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/{for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1);exit}}}')"
  [[ -n "${WAN_IF}" ]] || fail "No se pudo detectar WAN_IF (ip route get 1.1.1.1)."
  log "WAN_IF autodetectado: ${WAN_IF}"
else
  log "WAN_IF definido por config: ${WAN_IF}"
fi

# 4) Detección de conflictos de subredes P2P con otras instancias
tmp_py="$(mktemp)"
cat >"${tmp_py}" <<'PY'
import os, re, ipaddress, sys
env_dir = "/etc/wg-ns"
me = os.environ.get("NS")
mine = os.environ.get("SUBNET_P2P")
if not (me and mine):
    print("FALTAN VARS", file=sys.stderr); sys.exit(2)
mine_net = ipaddress.ip_network(mine, strict=False)
conflicts=[]
for fn in os.listdir(env_dir):
    if not fn.endswith(".env"):
        continue
    if fn == f"{me}.env":
        continue
    p=os.path.join(env_dir,fn)
    try:
        data=open(p,"r").read()
    except Exception:
        continue
    m=re.search(r'^\s*SUBNET_P2P\s*=\s*([^\s#]+)', data, flags=re.M)
    if not m:
        continue
    other=m.group(1)
    try:
        other_net=ipaddress.ip_network(other, strict=False)
    except Exception:
        continue
    if mine_net.overlaps(other_net):
        conflicts.append((fn, other))
if conflicts:
    print("CONFLICT", conflicts)
    sys.exit(1)
print("OK")
PY

export NS SUBNET_P2P
if ! python3 "${tmp_py}"; then
  rm -f "${tmp_py}"
  fail "Solape de subredes P2P con otras instancias. Revisa /etc/wg-ns/*.env"
fi
rm -f "${tmp_py}"

# 5) (Opcional) Comprobación HTTP rápida desde host (no bloqueante)
if command -v curl >/dev/null 2>&1; then
  curl -s --max-time 3 https://ifconfig.me >/dev/null 2>&1 || log "Aviso: curl externo falló (podría ser firewall)."
fi

log "Preflight OK. SUBNET_P2P=${SUBNET_P2P} WAN_IF=${WAN_IF} sin conflictos."
exit 0
