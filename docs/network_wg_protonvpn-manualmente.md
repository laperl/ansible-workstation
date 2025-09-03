# wgns-proton-manual.md

Guía **parametrizada** para levantar una VPN Proton (WireGuard) dentro de un **network namespace** aislado en Pop!\_OS/Ubuntu. Mantiene el **orden sagrado** indicado por Pops y añade ayudas/validaciones.

> **Notas rápidas**
>
> * Ejecuta en una terminal con privilegios (usa `sudo` donde se indica).
> * Sustituye valores de ejemplo por los tuyos o deja los que ya vienen del `.env`/facts si los usas con el *role*.
> * DNS por namespace se define en `/etc/netns/<ns>/resolv.conf`.

---

## 0) Variables (parametrizadas)

Copia/pega y ajusta solo lo necesario:

```bash
# === Identificadores ===
export NS="vpn1"                      # nombre del network namespace
export VETH_HOST="veth-${NS}"         # extremo que se QUEDA en el host
export VETH_NS="veth1"                # extremo DENTRO del netns (no usar 'eth0')

# === Red punto a punto /30 para el par veth ===
export SUBNET="192.168.254.0/30"
export HOST_IP="192.168.254.1"        # IP en el host (gateway del ns)
export NS_IP="192.168.254.2"          # IP en el netns

# === Interfaz de salida real a Internet ===
export WAN_IF="wlp4s0"                # p. ej. 'wlp4s0' (wifi) o 'enp3s0' (ethernet)

# === WireGuard dentro del namespace ===
export WG_IF="wg0"                    # nombre de la interfaz WG en el ns
export WG_ADDR="10.2.0.2/32"          # Address del cliente (del .conf original)
export CONF="/ruta/al/wg-${NS}_purowg.conf"  # conf PURA (wg-quick strip)

# === DNS del namespace ===
export DNS_VPN="10.2.0.1"             # DNS que usará el ns (p. ej. el de Proton)

# === Endpoint remoto (host:puerto) tal como aparecía en el .conf original ===
export ENDPOINT="es-xx.protonvpn.net:51820"

# Usuario no-root para pruebas en el ns (curl final)
export APP_USER="jaume"               # cámbialo por tu usuario real
```

---

## 1) Crear el namespace y subir loopback

```bash
sudo ip netns add "$NS"
sudo ip -n "$NS" link set lo up
ip netns list
# Verifica que existe y está up el loopback en el ns
sudo ip -n "$NS" addr show lo
```

---

## 2) Crear el par veth y mover un extremo al namespace

```bash
# Crea el "cable" virtual: veth-${NS} <-> veth1
sudo ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
# Pasa veth1 al namespace $NS
sudo ip link set "$VETH_NS" netns "$NS"
# Comprueba el extremo que queda en el host
ip link show "$VETH_HOST"
```

**Asignar IPs /30 y levantar interfaces**

```bash
# Host
sudo ip addr add "$HOST_IP"/30 dev "$VETH_HOST"
sudo ip link set "$VETH_HOST" up
ip -o -4 addr show dev "$VETH_HOST"

# Netns
sudo ip -n "$NS" addr add "$NS_IP"/30 dev "$VETH_NS"
sudo ip -n "$NS" link set "$VETH_NS" up
sudo ip -n "$NS" -o -4 addr show dev "$VETH_NS"
```

**Ruta por defecto provisional dentro del ns hacia el host**

```bash
sudo ip -n "$NS" route add default via "$HOST_IP" dev "$VETH_NS"
sudo ip netns exec "$NS" ip route
# Ping al gateway del ns (el host)
sudo ip netns exec "$NS" ping -c1 "$HOST_IP"
```

---

## 3) Habilitar forwarding + NAT en el host

> Opcional si usas el *role* con IPTABLES\_MANAGE\_NAT=1. Aquí en manual.

```bash
# Forwarding IPv4 (efímero; persistente: sysctl.conf)
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null

# NAT desde la subred del namespace hacia Internet por tu interfaz real
sudo iptables -t nat -A POSTROUTING -s "$SUBNET" -o "$WAN_IF" -j MASQUERADE

# Verificaciones
cat /proc/sys/net/ipv4/ip_forward      # Debe ser 1
sudo iptables -t nat -S POSTROUTING | grep MASQUERADE
```

**Probar salida provisional del ns (sin WG)**

```bash
# Ya añadimos la default provisional en el paso 2; probamos ICMP y rutas
sudo ip netns exec "$NS" ping -c1 1.1.1.1
sudo ip -n "$NS" route
```

---

## 4) Resolver IP del Endpoint y fijar ruta directa /32 a ese host

Evita que el handshake salga por el propio túnel.

```bash
ENDPOINT_HOST=${ENDPOINT%:*}
ENDPOINT_PORT=${ENDPOINT#*:}
EP_IP=$(getent ahostsv4 "$ENDPOINT_HOST" | awk 'NR==1{print $1}')
echo "Endpoint $ENDPOINT_HOST -> $EP_IP:$ENDPOINT_PORT"

# Ruta /32 dentro del ns HACIA el endpoint por el veth (no por wg0)
sudo ip -n "$NS" route add "$EP_IP"/32 via "$HOST_IP" dev "$VETH_NS"

# Verifica que esa IP va por $VETH_NS
a=$(sudo ip -n "$NS" route get "$EP_IP"); echo "$a"
```

---

## 5) Crear y mover la interfaz WireGuard al netns

```bash
# Crear wg0 en el host y moverla adentro del ns
sudo ip link add "$WG_IF" type wireguard
sudo ip link set "$WG_IF" netns "$NS"

# Verifica: no debe aparecer en el host
ip link show | grep -w "$WG_IF" || echo "OK (no está en host)"
# Debe aparecer (DOWN por ahora) en el ns
sudo ip -n "$NS" link show "$WG_IF"
```

---

## 6) Cargar configuración PURA y levantar WG

```bash
# Cargar claves, peers, AllowedIPs, Endpoint, Keepalive...
sudo ip netns exec "$NS" wg setconf "$WG_IF" "$CONF"
# Asignar Address del túnel (del conf original)
sudo ip -n "$NS" address add "$WG_ADDR" dev "$WG_IF"
# Subir wg0
sudo ip -n "$NS" link set "$WG_IF" up

# Verificación del estado de WG (handshake puede tardar unos segundos)
sudo ip netns exec "$NS" wg show
```

---

## 7) Enrutar todo el tráfico del ns por la VPN

```bash
sudo ip -n "$NS" route replace default dev "$WG_IF"
# Debe quedar: default dev wg0  (y mantenerse la ruta /32 al $EP_IP via $VETH_NS)
sudo ip -n "$NS" route
```

---

## 8) DNS propio del namespace (sin fugas)

```bash
sudo mkdir -p /etc/netns/"$NS"
echo "nameserver $DNS_VPN" | sudo tee /etc/netns/"$NS"/resolv.conf >/dev/null

# (opcional) probar resolución (usa el DNS del ns)
sudo ip netns exec "$NS" getent hosts example.com
# Verifica que resolv.conf del ns contiene tu DNS
sudo ip netns exec "$NS" cat /etc/resolv.conf
```

---

## 9) Comprobar salida real por la VPN

```bash
# Sustituye APP_USER por tu usuario normal para no correr como root
echo "IP pública (debería ser la de ProtonVPN):"
sudo ip netns exec "$NS" sudo -u "$APP_USER" curl -s https://ifconfig.me || true
```

---

## 10) (Opcional) Atajos útiles

```bash
# Entrar en un shell dentro del netns
sudo ip netns exec "$NS" sudo -u "$APP_USER" bash -l

# Ejecutar una app aislada en el ns (ejemplos)
sudo ip netns exec "$NS" sudo -u "$APP_USER" firefox &
sudo ip netns exec "$NS" sudo -u "$APP_USER" flatpak run com.brave.Browser &
```

---

## 11) (Opcional) Limpieza manual (down)

> Si no usas los scripts del role.

```bash
# Eliminar default del ns (si existe)
sudo ip netns exec "$NS" ip route | grep -q '^default ' && \
  sudo ip netns exec "$NS" ip route del default || true
# Bajar/eliminar WG
a=$(sudo ip -n "$NS" link show "$WG_IF" 2>/dev/null) && {
  sudo ip -n "$NS" link set "$WG_IF" down || true
  sudo ip -n "$NS" link del "$WG_IF"  || true
} || true
# Quitar ruta /32 al endpoint (si podemos recalcular)
if [[ -n "$ENDPOINT" ]]; then
  EP_IP=$(getent ahostsv4 "${ENDPOINT%:*}" | awk 'NR==1{print $1}') || true
  [[ -n "$EP_IP" ]] && sudo ip -n "$NS" route del "$EP_IP"/32 via "$HOST_IP" dev "$VETH_NS" || true
fi
# Borrar veth y netns
sudo ip link show "$VETH_HOST" >/dev/null 2>&1 && {
  sudo ip link set "$VETH_HOST" down || true
  sudo ip link del "$VETH_HOST" || true
}
sudo ip netns list | grep -qw "$NS" && sudo ip netns del "$NS" || true
# (opcional) limpiar DNS del ns
sudo rm -f "/etc/netns/$NS/resolv.conf" || true
```

---

## Problemas típicos (TL;DR)

* **No handshake**: asegúrate de que existe la **ruta /32 al Endpoint** dentro del ns por el veth (paso 4) y que la **default** final es por `wg0` (paso 7).
* **Sin DNS**: crea `/etc/netns/$NS/resolv.conf` con `nameserver $DNS_VPN` (paso 8).
* **Sin salida**: confirma `ip_forward=1` y la regla `MASQUERADE` con la **subred /30** correcta (paso 3).
* **Interfaces repetidas**: evita colisiones de nombres; `VETH_HOST` es único por ns y `VETH_NS` va *dentro* del ns.

---

## Anexos

* Este manual está preparado para integrarse con el *role* `network_wg_protonvpn` (facts y `.env` por instancia), pero funciona también en modo manual puro.
* Para automatizar el arranque/paro, usa las unidades `wg-ns@<instancia>.service` y los scripts `wgns-*.sh` del role.
