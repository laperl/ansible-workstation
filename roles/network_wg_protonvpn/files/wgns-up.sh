#!/usr/bin/env bash
# Levanta la VPN en netns (orden sagrado), SIN sudo (corre como root vía systemd).
set -euo pipefail
set -Ee
NS="${1:-}"; [[ -n "${NS}" ]] || { echo "Uso: $0 <instancia>"; exit 2; }

ENV_FILE="/etc/wg-ns/${NS}.env"
[[ -r "${ENV_FILE}" ]] || { echo "No existe ${ENV_FILE}"; exit 2; }
# shellcheck disable=SC1090
. "${ENV_FILE}"

log()  { logger -t wg-ns "up[${NS}] $*"; }
fail() { logger -t wg-ns "up[${NS}] ERROR: $*"; echo "ERROR: $*" >&2; exit 1; }
trap 'rc=$?; logger -t wg-ns "up[${NS}] ABORT rc=${rc} line=${LINENO}: ${BASH_COMMAND}"; exit $rc' ERR

: "${SUBNET_P2P:?}"; : "${HOST_IP:?}"; : "${NS_IP:?}"
: "${CONF:?}"; : "${DECRYPTED_CONF:?}"
[[ -r "${DECRYPTED_CONF}" ]] || fail "No puedo leer DECRYPTED_CONF=${DECRYPTED_CONF}"
[[ -r "${CONF}" ]]          || fail "No puedo leer CONF=${CONF}"

# Fallbacks desde el conf original (tolera espacios iniciales)
WG_IF="${WG_IF:-}"
if [[ -z "${WG_IF}" ]]; then WG_IF="wg0"; log "WG_IF vacío, usando fallback: ${WG_IF}"; fi

WG_ADDR="${WG_ADDR:-}"
if [[ -z "${WG_ADDR}" ]]; then
  WG_ADDR="$(sed -nE 's/^[[:space:]]*Address[[:space:]]*=[[:space:]]*([^,[:space:]]+).*$/\1/p' "${DECRYPTED_CONF}" | head -1)"
  [[ -n "${WG_ADDR}" ]] || fail "No se pudo extraer Address= del conf original"
  log "WG_ADDR vacío, extraído del conf: ${WG_ADDR}"
fi

DNS_VPN="${DNS_VPN:-}"
if [[ -z "${DNS_VPN}" ]]; then
  DNS_VPN="$(sed -nE 's/^[[:space:]]*DNS[[:space:]]*=[[:space:]]*([^,[:space:]]+).*$/\1/p' "${DECRYPTED_CONF}" | head -1 || true)"
  [[ -n "${DNS_VPN}" ]] && log "DNS_VPN vacío, extraído del conf: ${DNS_VPN}" || log "DNS no presente en conf"
fi

if [[ -n "${ENDPOINT_OVERRIDE:-}" ]]; then
  ENDPOINT_HOST="${ENDPOINT_OVERRIDE%:*}"
  ENDPOINT_PORT="${ENDPOINT_OVERRIDE#*:}"
else
  ep_line="$(sed -nE 's/^[[:space:]]*Endpoint[[:space:]]*=[[:space:]]*([^#]+).*$/\1/p' "${DECRYPTED_CONF}" | head -1)"
  ENDPOINT_HOST="${ep_line%:*}"; ENDPOINT_PORT="${ep_line#*:}"
fi
[[ -n "${ENDPOINT_HOST}" && -n "${ENDPOINT_PORT}" ]] || fail "No se pudo determinar Endpoint (host/port)"
EP_IP="$(getent ahostsv4 "${ENDPOINT_HOST}" | awk 'NR==1{print $1}')"
[[ -n "${EP_IP}" ]] || fail "No se pudo resolver IP para ${ENDPOINT_HOST}"

# PASO 1: netns + loopback
ip netns list | grep -qw "${NS}" || { ip netns add "${NS}"; log "Creado netns ${NS}"; }
ip -n "${NS}" link set lo up

# PASO 2: veth par
ip link show "${VETH_HOST}" >/dev/null 2>&1 || {
  ip link add "${VETH_HOST}" type veth peer name "${VETH_NS}"
  ip link set "${VETH_NS}" netns "${NS}"
  log "Creado veth: ${VETH_HOST} <-> ${VETH_NS}@${NS}"
}

# PASO 3: IPs y UP
ip -o -4 addr show dev "${VETH_HOST}" | grep -qw "${HOST_IP}" || ip addr add "${HOST_IP}/30" dev "${VETH_HOST}"
ip link set "${VETH_HOST}" up
ip -n "${NS}" -o -4 addr show dev "${VETH_NS}" | grep -qw "${NS_IP}" || ip -n "${NS}" addr add "${NS_IP}/30" dev "${VETH_NS}"
ip -n "${NS}" link set "${VETH_NS}" up

# PASO 4: default provisional por veth
ip -n "${NS}" route | grep -q '^default ' || ip -n "${NS}" route add default via "${HOST_IP}" dev "${VETH_NS}" || true

# PASO 5: (opcional) NAT si está activado
if [[ "${IPTABLES_MANAGE_NAT:-0}" == "1" ]]; then
  iptables -t nat -S POSTROUTING | grep -qE "--source ${SUBNET_P2P} .* -o ${WAN_IF} .* -j MASQUERADE" || {
    iptables -t nat -A POSTROUTING -s "${SUBNET_P2P}" -o "${WAN_IF}" -j MASQUERADE
    log "Añadida MASQUERADE ${SUBNET_P2P} -> ${WAN_IF}"
  }
fi

# PASO 6: ruta /32 al endpoint (por veth)
ip -n "${NS}" route | grep -q "^${EP_IP}/32 " || ip -n "${NS}" route add "${EP_IP}/32" via "${HOST_IP}" dev "${VETH_NS}"

# PASO 7: interfaz WireGuard en el netns
ip link show "${WG_IF}" >/dev/null 2>&1 && ip link set "${WG_IF}" netns "${NS}" || true
ip -n "${NS}" link show "${WG_IF}" >/dev/null 2>&1 || { ip link add "${WG_IF}" type wireguard; ip link set "${WG_IF}" netns "${NS}"; }

# PASO 8: setconf + UP
ip netns exec "${NS}" wg setconf "${WG_IF}" "${CONF}"
ip -n "${NS}" -o -4 addr show dev "${WG_IF}" | grep -qw "$(echo "${WG_ADDR}" | cut -d/ -f1)" || ip -n "${NS}" addr add "${WG_ADDR}" dev "${WG_IF}"
ip -n "${NS}" link set "${WG_IF}" up

# PASO 9: default por wg
ip -n "${NS}" route replace default dev "${WG_IF}"

# PASO 10: DNS del namespace
if [[ -n "${DNS_VPN:-}" ]]; then
  mkdir -p "/etc/netns/${NS}"
  echo "nameserver ${DNS_VPN}" > "/etc/netns/${NS}/resolv.conf"
  log "DNS del netns = ${DNS_VPN}"
fi

# Pruebas no bloqueantes
ip netns exec "${NS}" ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 && log "Ping OK en netns" || log "Ping KO (handshake puede tardar)"
ip netns exec "${NS}" wg show >/dev/null 2>&1 && log "wg show OK" || log "wg show ERROR"

log "UP OK (WG_IF=${WG_IF}, EP=${ENDPOINT_HOST}:${ENDPOINT_PORT}, EP_IP=${EP_IP})"
exit 0
