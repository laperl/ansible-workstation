# network\_wg\_protonvpn

Este role prepara la infraestructura para levantar una o varias VPN Proton (WireGuard) en **namespaces** aislados.

---

## Parámetro por VPN: autostart

* `autostart: true`  → se habilitará el servicio systemd al arranque.
* `autostart: false` → arranque manual (útil para pruebas o VPNs puntuales).

---

## Flujo (resumen)

1. **Cargar variables y validar estructura.**
2. **Desencriptar `.conf` (SOPS) y convertir con `wg-quick strip` → `setconf`.**

   * Implementado en `tasks/prepare_conf.yml`.
   * Para cada instancia:

     * Desencripta el `.conf` original con `community.sops.sops` (en el controlador).
     * Extrae líneas `Address=` y `DNS=` para usarlas después (IPs y resolv.conf del namespace).
     * Normaliza un nombre corto seguro (≤15 caracteres) para satisfacer restricciones de `wg-quick`.
     * Ejecuta `wg-quick strip` para generar un fichero “puro WG” sin `Address`/`DNS`.
     * Publica *facts* por instancia en `network_wg_protonvpn_facts[<name>]`:

       * `purowg_conf`, `decrypted_conf`, `wg_addr`, `dns_original`, `short_conf_path`, `short_base`.
     * El fichero corto temporal se borra siempre al finalizar.
     * Seguridad: todo con `no_log: true` y permisos `0600`.
3. (Futuro) Crear netns + veth + IPs + rutas.
4. (Futuro) Cargar WG, DNS por netns (`/etc/netns/<ns>/resolv.conf`).
5. (Futuro en Pop!\_OS 22.04) NAT con **iptables** (POSTROUTING MASQUERADE).

---

## Ejemplo rápido de uso (dry-run)

```bash
ansible-playbook playbooks/network_wg_protonvpn_dryrun.yml -i localhost,
```

En el dry-run puedes inspeccionar los *facts* publicados para verificar que el parsing de Address/DNS y `wg-quick strip` funcionan.

---

## Detalles técnicos relevantes

* Se usa **`community.sops`** para desencriptar en el controlador (no en el host remoto).
* `wg-quick strip` requiere un basename ≤15 → se genera un nombre corto derivado del `.sops.yaml`.
* Los ficheros `decrypted_conf` y `purowg_conf` son temporales y se mantendrán hasta que el role o los scripts de *teardown* los eliminen.

---

## Próximos pasos (planeados)

* Preflight: detección de `WAN_IF`, conectividad y conflictos de subred.
* Creación idempotente de netns/veth.
* Ruta directa al Endpoint para evitar hairpin.
* Configuración de interfaz WG y rutas por defecto.
* DNS propio por namespace (`/etc/netns/<ns>/resolv.conf`).
* Forwarding + NAT con iptables.
* Unidades systemd y *scripts* auxiliares (`wgns-preflight.sh`, `wgns-up.sh`, `wgns-down.sh`).
