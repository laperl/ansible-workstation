# Role: network_wg_protonvpn

Levanta una o varias VPN Proton (WireGuard) en **network namespaces** aislados, con configuración `wg setconf` (derivada de ficheros `wg-quick` cifrados con **SOPS**).

## Variables (defaults)

- `network_wg_protonvpn_instances`: lista de instancias. Campos:
  - `name` (string): nombre del namespace y de la instancia.
  - `autostart` (bool): `true` -> se habilitará el servicio systemd al inicio; `false` -> arranque manual.
  - `wg_conf_sops` (path): ruta al `.conf` wg-quick **cifrado con SOPS**.
  - `wg_if` (string): interfaz WireGuard dentro del netns (p. ej. `wg0`).
  - `subnet_p2p`, `host_ip`, `ns_ip`: red /30 para el par veth.
  - `dns_ns` (string): DNS dentro del netns (si vacío, se intentará usar el del conf original).
  - `wan_if` (string): interfaz WAN; si vacío, se detecta automáticamente.
  - `endpoint_override` (string): `host:port` para forzar endpoint (opcional).

- `network_wg_protonvpn_global`:
  - `ip_forward_persistent` (bool): asegurar `net.ipv4.ip_forward=1`.
  - `iptables_manage_nat` (bool): si `true`, el role gestionará `iptables -t nat -A POSTROUTING -j MASQUERADE`.
  - `iptables_nat_subnets` (list): subredes a mascara-dear.
  - `systemd_unit_name` (string): nombre del template de servicio (p. ej. `wg-ns@.service`).

## Requisitos

- Ficheros `.conf` de Proton en formato `wg-quick`, **cifrados con SOPS**.
- `wg-quick strip` presente (`wireguard-tools`).
- Pop!\_OS 22.04 con `iptables` para NAT.

## Notas

- Los `.conf` `wg-quick` se convierten con `wg-quick strip` para `wg setconf`.
- DNS por namespace se gestiona con `/etc/netns/<ns>/resolv.conf`.
