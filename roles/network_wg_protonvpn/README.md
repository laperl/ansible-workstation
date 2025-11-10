# roles/network\_wg\_protonvpn — README.md

## Propósito

Desplegar una o varias **ProtonVPN (WireGuard)** dentro de **network namespaces** (netns) en Pop!\_OS/Ubuntu, con rutas, DNS y (opcional) NAT aislados, controlado por **systemd** y archivos **.env** por instancia.

## Requisitos

* Pop!\_OS/Ubuntu 22.04 con `wireguard-tools` (`wg`, `wg-quick`) y `iptables`.
* En el **controlador Ansible**: binario `sops` en `PATH` (Ver docs/sops_uso.md).
* Colección `community.sops` (ya declarada en `requirements.yml`).

## Variables (API)

Ejemplo mínimo en `group_vars/all` o en tu inventario:

```yaml
network_wg_protonvpn_instances:
  - name: "vpn1"                  # nombre del netns/instancia
    autostart: true               # habilitar unidad al boot (no arranca hasta que invoques systemctl/play)
    wg_conf_sops: "{{ playbook_dir }}/secrets/wg-protonvpn/my.conf.sops.yaml"
    wg_if: "wg0"                  # interfaz WG dentro del netns
    subnet_p2p: "192.168.254.0/30"
    host_ip: "192.168.254.1"
    ns_ip:   "192.168.254.2"
    dns_ns:  "10.2.0.1"           # si vacío → usa DNS= del conf original
    wan_if: ""                    # si vacío → autodetectar en preflight
    endpoint_override: ""         # opcional: "host:puerto" para forzar endpoint
```

## Qué instala

* **Confs WG** en `conf_dir` (`/etc/wireguard` por defecto):

  * `<instancia>.original.conf` (wg-quick original, desencriptado desde SOPS)
  * `<instancia>.purowg.conf` (purificado con `wg-quick strip` para `wg setconf`)
* **Unidad systemd**: `/etc/systemd/system/wg-ns@.service` (plantilla instanciable)
* **Scripts** en `/usr/local/sbin/`:

  * `wgns-preflight.sh` — conectividad, autodetección de `WAN_IF` y solapes de subred /30
  * `wgns-up.sh` — crea netns+veth, IPs/30, ruta /32 al endpoint, levanta WG, default por WG, DNS del netns
  * `wgns-down.sh` — revierte todo y limpia NAT efímero si procede
  * `MI_wgns-exec.bash` — **wrapper sencillo** para ejecutar 1 app dentro del netns
* **.env por instancia**: `/etc/wg-ns/<instancia>.env`

## Flujo del rol

1. **Validación** de estructura/formatos (`tasks/validate_vars.yml`).
2. **SOPS + strip** por instancia (`tasks/prepare_conf.yml`):

   * Desencripta `.conf` (YAML con `wg_conf` o `.conf` plano).
   * Extrae `Address=` y `DNS=` y publica *facts*.
   * Genera `*.purowg.conf` con `wg-quick strip` y persiste ambos ficheros con `0600`.
3. **Preflight/instalación** (`tasks/preflight_install.yml`): directorios, scripts, unit, `.env` por instancia; habilita servicio si `autostart: true` (estado `stopped`).

## Uso

### Dry‑run (ver parsing de confs)

```bash
ansible-playbook playbooks/network_wg_protonvpn_dryrun.yml -i localhost,
```

### Aplicar y operar

```bash
ansible-playbook site.yml -t network_wg_protonvpn -i localhost,

# Arrancar/parar una instancia
sudo systemctl start  wg-ns@vpn1
sudo systemctl stop   wg-ns@vpn1
sudo systemctl enable wg-ns@vpn1    # si autostart=true ya queda habilitada

# Logs
journalctl -u wg-ns@vpn1 -e -n 200
journalctl -t wg-ns   -e -n 200
```

## Ejecutar una app dentro del netns (wrapper sencillo)

Script instalado: `/usr/local/sbin/MI_wgns-exec.bash`

**Uso básico:**

```bash
# Ejecuta una app/orden en el netns como tu usuario normal
sudo MI_wgns-exec.bash vpn1 -- brave-browser --profile-directory="crypto"

# Otra app
sudo MI_wgns-exec.bash vpn1 -- thunderbird
```

**Script (para referencia):**

```bash
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
```

> Nota: si alguna app GUI no arranca por variables de entorno, prueba lanzarla desde una terminal gráfica del propio usuario o añade `env VAR=...` delante del comando.

## Tests de humo

```bash
# IP pública por Proton
sudo ip netns exec vpn1 curl -s https://ifconfig.me

# DNS del namespace
sudo ip netns exec vpn1 getent hosts example.com
sudo ip netns exec vpn1 cat /etc/resolv.conf

# Estado WG + handshake
sudo ip netns exec vpn1 wg show
```

## Seguridad / buenas prácticas

* Confs con permisos `0600` y `owner=root`. Temporales intermedios se borran.
* Unidad con `NoNewPrivileges=true` y capacidades de red acotadas.
* **iptables NAT** sólo si `iptables_manage_nat: true` (se añade al subir y se elimina al bajar).
* Activa `net.ipv4.ip_forward=1` (el rol puede dejarlo persistente si `ip_forward_persistent: true`).

## Troubleshooting

* Sin handshake: revisa ruta `/32` al endpoint (`ip r get <EP_IP>` dentro del netns), `default dev wg0`, y logs `journalctl -t wg-ns`.
* DNS: comprueba `/etc/netns/<ns>/resolv.conf` y `dns_ns`.
* Sin salida en host: `ip route get 1.1.1.1` debe devolver `dev <if>`.
