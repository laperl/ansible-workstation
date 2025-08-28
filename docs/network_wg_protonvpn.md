# network_wg_protonvpn (borrador)

Este role prepara la infraestructura para levantar una o varias VPN Proton (WireGuard) en **namespaces** aislados.

## Parámetro por VPN: autostart
- `autostart: true`  -> se habilitará el servicio systemd al arranque.
- `autostart: false` -> arranque manual (útil para pruebas o VPNs puntuales).

## Flujo (resumen)
1. Cargar variables y validar estructura.
2. (Futuro) Desencriptar `.conf` (SOPS) y convertir con `wg-quick strip` → `setconf`.
3. (Futuro) Crear netns + veth + IPs + rutas.
4. (Futuro) Cargar WG, DNS por netns (`/etc/netns/<ns>/resolv.conf`).
5. (Futuro en Pop!\_OS 22.04) NAT con **iptables** (POSTROUTING MASQUERADE).

## Prueba rápida (dry-run):
```bash
ansible-playbook playbooks/network_wg_protonvpn_dryrun.yml -i localhost,
```

> Esta doc crecerá a medida que implementemos los siguientes puntos (SOPS, netns, systemd, NAT, etc.).
> - `wg-quick strip` (para `wg setconf`). :contentReference[oaicite:7]{index=7}
> - `/etc/netns/<ns>/resolv.conf` (DNS por namespace). :contentReference[oaicite:8]{index=8}
> - `NetworkManager-wait-online.service` / `network-online.target`. :contentReference[oaicite:9]{index=9}
> - NAT con `iptables` (POSTROUTING/MASQUERADE). :contentReference[oaicite:10]{index=10}
