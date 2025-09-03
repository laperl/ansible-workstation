# docs/network\_wg\_protonvpn.md

## Resumen

Role para aislar tráfico por **network namespaces** y túneles **WireGuard** de ProtonVPN, con **DNS por namespace** y **NAT** opcional.

## Arquitectura

* **netns**: aislamiento de pila de red, rutas y dispositivos.
* **veth /30**: par virtual host↔netns (`host_ip` y `ns_ip`).
* **Ruta /32 al endpoint** por la veth para evitar hairpin al levantar WG.
* **WG en el netns** (`wg setconf` con `*.purowg.conf`), **default** por WG.
* **DNS por netns** en `/etc/netns/<ns>/resolv.conf`.
* **NAT (iptables)** efímero opcional (POSTROUTING MASQUERADE por `WAN_IF`).

## Detalle de tareas

* `validate_vars.yml`: estructura y formatos de IP/CIDR.
* `prepare_conf.yml`: desencripta (SOPS), extrae `Address`/`DNS`, normaliza basename ≤15, ejecuta `wg-quick strip`, persiste confs y publica facts.
* `preflight_install.yml`:

  * Crea directorios (`/usr/local/sbin`, `/etc/systemd/system`, `/etc/wg-ns`).
  * Instala scripts `wgns-*.sh` y **`MI_wgns-exec.bash`**.
  * Instala unit `wg-ns@.service` y `.env` por instancia.
  * Habilita `wg-ns@<instancia>` si `autostart: true` (en `stopped`).

## Operativa

1. Ejecuta el play del role.
2. Arranca la instancia con systemd: `sudo systemctl start wg-ns@vpn1`.
3. Lanza una app dentro del netns: `sudo MI_wgns-exec.bash vpn1 -- <comando>`.
4. Verifica con los **tests de humo**.

## Mantenimiento

* **Logs**: `journalctl -u wg-ns@<ns>`, `journalctl -t wg-ns`.
* **Limpieza**: `systemctl stop wg-ns@<ns>` y `wgns-down.sh` ya elimina veth/netns y NAT efímero.
* **Sysctl**: si `ip_forward_persistent: true`, se instala `/etc/sysctl.d/99-wgns-forward.conf` con `net.ipv4.ip_forward=1`.

## Preguntas frecuentes

* ¿Puedo usar mi propio DNS? Sí: pon `dns_ns` en la instancia o deja vacío para usar el `DNS=` del conf original.
* ¿Qué pasa si no defino `wan_if`? Se autodetecta en preflight (`ip route get 1.1.1.1`).
* ¿Puedo usar varias instancias a la vez? Sí, el preflight detecta **solapes** de subred y falla si los hay.
# docs/network\_wg\_protonvpn.md
