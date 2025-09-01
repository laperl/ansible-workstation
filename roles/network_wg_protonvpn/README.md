# Role: network\_wg\_protonvpn

Levanta una o varias VPN Proton (WireGuard) en **network namespaces** aislados, usando `wg setconf` (a partir de ficheros `wg-quick` cifrados con **SOPS**).

> **Novedad (paso 2)**: se incorpora `tasks/prepare_conf.yml`, que **desencripta** el `.conf` original (SOPS), **extrae** `Address`/`DNS`, **normaliza** el nombre del fichero para `wg-quick` (≤15 caracteres) y genera una **configuración purificada** con `wg-quick strip` para usar con `wg setconf`.

---

## Requisitos

* Pop!\_OS (Ubuntu 22.04) con `wireguard-tools` (`wg`, `wg-quick`).
* En el **controlador**: binario `sops` accesible en `PATH`.
* Colecciones Ansible:

  * `community.sops` (lookup `community.sops.sops`).
  * `community.general`, `ansible.posix` (según el resto del proyecto).

> En este repo, `community.sops` ya figura en `requirements.yml` y `sops` se instala en el controlador desde el role `base`.

---

## Variables

```yaml
network_wg_protonvpn_instances:
  - name: "vpn1"                  # nombre del netns y de la instancia
    autostart: true               # habilitar unidad systemd al arranque
    wg_conf_sops:
      {{ playbook_dir }}/secrets/wg-protonvpn/repos-wgproton.conf.sops.yaml
    wg_if: "wg0"                  # interfaz WG dentro del netns
    subnet_p2p: "192.168.254.0/30"
    host_ip: "192.168.254.1"
    ns_ip:   "192.168.254.2"
    dns_ns:  "10.2.0.1"          # si vacío → usa DNS del conf original
    wan_if: ""                    # autodetect
    endpoint_override: ""         # host:port opcional

network_wg_protonvpn_global:
  ip_forward_persistent: true
  iptables_manage_nat: false
  iptables_nat_subnets: []
  systemd_unit_name: "wg-ns@.service"
```

---

## Flujo de tareas actual

1. **Validación**: `tasks/validate_vars.yml` asegura estructura y formatos de IP.
2. **Plan (debug)**: `tasks/debug_plan.yml` muestra el despliegue calculado.
3. **Preparación de confs**: `tasks/prepare_conf.yml` (detalle abajo).

En `tasks/main.yml`:

```yaml
- import_tasks: validate_vars.yml
- import_tasks: debug_plan.yml
- include_tasks: prepare_conf.yml
  loop: "{{ network_wg_protonvpn_instances }}"
  loop_control: { loop_var: instance }
```

---

## ¿Qué hace `tasks/prepare_conf.yml`?

Para **cada instancia** (`loop_var: instance`):

1. **Desencripta** el `.conf` `wg-quick` con `lookup('community.sops.sops', instance.wg_conf_sops)` **en el controlador**.
2. **Extrae** `Address=` y `DNS=` (pueden ser listas separadas por comas) y las guarda para pasos posteriores.
3. **Normaliza** un *basename* corto y seguro (solo `[A-Za-z0-9_+=.-]`, truncado a 15) y crea `/tmp/<short>conf` para satisfacer la restricción de `wg-quick` (nombres ≤15 + `conf`).
4. Ejecuta `wg-quick strip` sobre ese fichero corto y **genera** una conf “pura WG” (sin `Address`/`DNS`) lista para `wg setconf`.
5. **Publica facts** por instancia en `network_wg_protonvpn_facts[<name>]`:

   * `purowg_conf`: ruta al fichero purificado.
   * `decrypted_conf`: ruta al `.conf` desencriptado original (temporal).
   * `wg_addr`: línea `Address` original (p.ej. `10.2.0.2/32`).
   * `dns_original`: línea `DNS` original (si existía).
   * `short_conf_path`: path intermedio `/tmp/<short>conf` (se elimina al final de la tarea).
   * `short_base`: basename corto calculado (≤15).

### Seguridad y limpieza

* Todo el material sensible se maneja con `no_log: true` y permisos `0600`.
* Se **elimina siempre** el fichero `/tmp/<short>conf` (solo necesario para `wg-quick strip`).
* Los ficheros temporales `decrypted_conf` y `purowg_conf` **persisten** para los siguientes pasos del role (creación de interfaz WG, systemd, etc.). Se prevé su limpieza controlada al **bajar** la VPN (en tareas posteriores como `wgns-down.sh`/handlers o al final del role si procede).

---

## Ejecución (dry-run útil para verificar parsing)

```bash
ansible-playbook playbooks/network_wg_protonvpn_dryrun.yml -i localhost,
```

Revisa en el output los *facts* publicados (con una tarea de debug opcional) y que `wg-quick strip` no marque cambios (se usa `changed_when: false`).

---

## Próximos pasos (planeados)

* **Preflight** (detección `WAN_IF`, conectividad, conflictos de subred /30).
* **Netns + veth** (creación idempotente, IPs y rutas p2p).
* **Ruta directa al Endpoint** (evitar hairpin al levantar WG).
* **Interfaz WireGuard en netns** (`wg setconf`, asignación `WG_ADDR`).
* **Rutas y DNS por namespace** (`/etc/netns/<ns>/resolv.conf`).
* **Forwarding + NAT (iptables)**.
* **Unidades systemd** (`wg-ns@.service`) y *scripts* auxiliares.

Para la explicación extendida y troubleshooting, consulta **`docs/network_wg_protonvpn.md`** (ver enlace en el repo).
