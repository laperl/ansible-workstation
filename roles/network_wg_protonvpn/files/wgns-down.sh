#!/usr/bin/env bash
set -euo pipefail
set -Ee
NS="${1:-}"; [[ -n "${NS}" ]] || { echo "Uso: $0 <instancia>"; exit 2; }

ENV_FILE="/etc/wg-ns/${NS}.env"
[[ -r "${ENV_FILE}" ]] || { echo "No existe ${ENV_FILE}"; exit 2; }
# shellcheck disable=SC1090
. "${ENV_FILE}"

log()  { logger -t wg-ns "down[${NS}] $*"; }
warn() { logger -t wg-ns "down[${NS}] AVISO: $*"; }
trap 'rc=$?; logger -t wg-ns "down[${NS}] ABORT rc=${rc} line=${LINENO}: ${BASH_COMMAND}"; exit $rc' ERR

WG_IF="${WG_IF:-wg0}"

# Quitar default (si existe)
ip netns list | grep -qw "${NS}" && { ip netns exec "${NS}" ip route | grep -q '^default ' && ip netns exec "${NS}" ip route del default || true; }

# Bajar/eliminar WG
if ip netns list | grep -qw "${NS}"; then
  if ip -n "${NS}" link show "${WG_IF}" >/dev/null 2>&1; then
    ip -n "${NS}" link set "${WG_IF}" down || true
    ip -n "${NS}" link del "${WG_IF}"  || true
    log "Interfaz ${WG_IF} eliminada"
  fi
fi

# Quitar ruta /32 al endpoint si podemos recalcular
EP_IP=""
if [[ -r "${DECRYPTED_CONF}" ]]; then
  ep_line="$(sed -nE 's/^[[:space:]]*Endpoint[[:space:]]*=[[:space:]]*([^#]+).*$/\1/p' "${DECRYPTED_CONF}" | head -1)"
  ep_host="${ENDPOINT_OVERRIDE:-${ep_line%:*}}"
  EP_IP="$(getent ahostsv4 "${ep_host}" | awk 'NR==1{print $1}')"
fi
[[ -n "${EP_IP}" ]] && ip netns list | grep -qw "${NS}" && ip -n "${NS}" route del "${EP_IP}/32" via "${HOST_IP}" dev "${VETH_NS}" || true

# veth + netns
ip link show "${VETH_HOST}" >/dev/null 2>&1 && { ip link set "${VETH_HOST}" down || true; ip link del "${VETH_HOST}" || true; log "Interfaz ${VETH_HOST} eliminada"; }
ip netns list | grep -qw "${NS}" && { ip netns del "${NS}" || true; log "netns ${NS} eliminado"; }

# NAT invertido si se gestionó
if [[ "${IPTABLES_MANAGE_NAT:-0}" == "1" ]]; then
  iptables -t nat -S POSTROUTING | grep -qE "--source ${SUBNET_P2P} .* -o ${WAN_IF} .* -j MASQUERADE" && {
    iptables -t nat -D POSTROUTING -s "${SUBNET_P2P}" -o "${WAN_IF}" -j MASQUERADE || true
    log "Regla MASQUERADE eliminada (${SUBNET_P2P} -> ${WAN_IF})"
  }
fi

# 6) (Opcional) No eliminamos /etc/netns/${NS}/resolv.conf para facilitar debug;
#    si quieres limpiarlo del todo, descomenta:
sudo rm -f "/etc/netns/${NS}/resolv.conf" || true

log "DOWN completado para ${NS}"
exit 0
