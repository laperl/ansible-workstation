# Estrategia DNS con Podman (slirp) + Navegadores (DoH)

> **Objetivo**: Ejecutar navegadores dentro de contenedores Podman **rootless** con **slirp4netns** (sin `--network=host`), evitando usar el DNS del sistema/contendor y forzando **DNS-over-HTTPS (DoH)** del propio navegador (Mullvad/Brave/Tor). Así, **todas** las resoluciones van por DoH del navegador,
> excepto el **bootstrap** inicial del host DoH si no se configura `bootstrapAddress`.

---

## 1) Modelo de red y DNS (visión general)

* **Capa contenedor (slirp4netns)**

  * Rootless Podman crea una pila virtual con DNS sintético **`10.0.2.3`** y añade *fallbacks* (p. ej. **1.1.1.1**, **1.0.0.1**).
  * Por diseño, **slirp no "hereda"** el `resolv.conf` de la VPN del host/netns. Su objetivo es proporcionar conectividad mínima aislada, no replicar la config DNS del host/netns.

* **Capa navegador (DoH)**

  * El navegador resuelve **por DoH** (HTTPS) hacia un proveedor específico (p. ej. **Mullvad DoH** `https://dns.mullvad.net/dns-query`).
  * Con **TRR-only** (Firefox/Mullvad `mode=3`) o **políticas en Brave/Tor**, **no** se usa el DNS del sistema del contenedor.
  * **Bootstrap**: para contactar el host DoH (p. ej., `dns.mullvad.net`) el navegador podría necesitar **una** resolución inicial usando el DNS del sistema. Se elimina fijando **`bootstrapAddress`** (Firefox/Mullvad/Tor) o bloqueando *fallbacks* (Brave) con política + firewall.

**Estrategia**: Mantener **slirp** por simplicidad, pero **delegar totalmente** la resolución a DoH del navegador. Opcionalmente, fijar `bootstrapAddress` para que **ni la primera** resolución dependa de slirp.

---

## 2) Riesgos y limitaciones (por qué slirp no usa el DNS de la VPN)

* **slirp4netns** provee un stack de red de usuario mínimo con su **propio DNS** (10.0.2.3) y *fallbacks*, no el de tu VPN. No hay mecanismo estándar en rootless para “engancharse” a DNS del netns de una VPN externa.
* **Riesgo de fugas** si **no** se usa DoH: el contenedor podría consultar a 1.1.1.1/1.0.0.1 (o resolver por 10.0.2.3)
  fuera del túnel de tu VPN (según rutas).
* **Con DoH (recomendado)**: las consultas DNS van cifradas por HTTPS al proveedor configurado en el navegador. La única ventana potencial es el **bootstrap** del host DoH si no se fija `bootstrapAddress`.

---

## 3) Configuración por navegador

### 3.1 Mullvad Browser (basado en Firefox)

* **Activar DoH Mullvad (TRR-only)**

  1. `about:preferences#privacy → Enable DNS over HTTPS → Max Protection`.
  2. Proveedor: **Mullvad (Default)** (`https://dns.mullvad.net/dns-query`).
  3. `about:config`:

     * `network.trr.mode = 3`  *(TRR only)*
     * `network.trr.uri = https://dns.mullvad.net/dns-query`
     * **Opcional recomendado**: `network.trr.bootstrapAddress = <IP_de_dns.mullvad.net>`

       * Obtén la IP en `about:networking → DNS Lookup → dns.mullvad.net`.

* **Verificación (solo navegador)**

  * `about:networking → DNS`:

    * **DoH URL** debe ser `https://dns.mullvad.net/dns-query`.
    * **DoH Mode** debe ser `3`.
    * Tras "Clear DNS Cache" y recargar sitios: columna **TRR = true**.
  * `https://1.1.1.1/help` → "**Using DNS over HTTPS: Yes**".
  * `https://am.i.mullvad.net/ip` → comprueba IP (del túnel si procede).

---

### 3.2 Brave (Chromium)

* **Activar DoH (Mullvad) vía UI**

  1. `brave://settings/security` → **Use secure DNS**: ON.
  2. **With** → **Custom**: `https://dns.mullvad.net/dns-query`.

* **Endurecer (evitar fallback al DNS del sistema)**

  * Brave/Chromium puede hacer fallback si el DoH falla. Para aproximar **DoH-only**:

    * Política de empresa (Linux): crear `/etc/opt/brave/policies/managed/doh.json`:

      ```json
      {
        "BuiltInDnsClientEnabled": true,
        "DnsOverHttpsMode": "secure",
        "DnsOverHttpsTemplates": "https://dns.mullvad.net/dns-query{?dns}"
      }
      ```
    * **Complemento** (opcional fuera del contenedor): bloquear **UDP/TCP 53** en el netns/host para ese contenedor y permitir sólo HTTPS al/los IPs de `dns.mullvad.net`. Esto fuerza comportamiento "DoH-only de facto".

* **Verificación (solo navegador)**

  * `brave://net-internals/#dns` → revisar estado y vaciar caché.
  * `https://1.1.1.1/help` → "**DNS over HTTPS: Yes**".
  * Cargar sitios y verificar que resuelven sin errores con DoH activado.

---

### 3.3 Tor Browser

> Tor Browser no usa DoH: envía las consultas a través del **proxy SOCKS de Tor**, resolviendo en los **exit relays** (o internamente según versión/config). No emplea el DNS del sistema del contenedor.

* **Ajustes clave**

  * No habilitar DoH: Tor ya encapsula resolución en el circuito Tor.
  * Mantener la configuración por defecto (resolución via Tor). Evitar extensiones o cambios que intenten usar DNS del sistema.

* **Verificación (solo navegador)**

  * `about:networking → DNS` mostrará entradas resueltas,
    pero la ruta sale por Tor (no depende de `/etc/resolv.conf`).
  * Pruebas de IP: `https://check.torproject.org` (confirmar que estás en Tor).

---

## 4) Recomendaciones operativas (slirp + DoH)

1. **Mantener slirp** por simplicidad en rootless.
2. **Delegar resolución al navegador**:

   * Mullvad Browser: TRR-only a `dns.mullvad.net` + `bootstrapAddress`.
   * Brave: DoH Mullvad + política; opcionalmente bloquear 53 a nivel netns para evitar fallback.
   * Tor: dejar que resuelva via Tor (sin DoH).
3. **Verificar siempre desde el navegador** (sin herramientas externas):

   * Mullvad/Tor: `about:networking → DNS`, "Clear cache" y observar **TRR=true** (Mullvad) o actividad con Tor.
   * Brave: `brave://net-internals/#dns` y `https://1.1.1.1/help`.
4. **Riesgo residual**: el **bootstrap** del host DoH si no defines `bootstrapAddress` (en Firefox/Mullvad). Mitígalo definiendo esa IP. En Brave la mitigación es política + bloqueo de 53 para impedir fallback.

---

## 5) FAQ rápida

* **¿Por qué slirp no usa el DNS de mi VPN?**
  Porque slirp4netns implementa su propia pila NAT/virt con DNS sintético (10.0.2.3) y no está diseñado para heredar `resolv.conf` del host/netns externo en modo rootless.

* **¿Hay fuga DNS si uso DoH-only?**
  No: las consultas van por HTTPS al proveedor DoH. La ventana es el **bootstrap** si no configuras `bootstrapAddress` (Firefox/Mullvad).

* **¿Qué pasa si cae el DoH?**

  * Mullvad/Firefox TRR-only: el navegador **no** resuelve (verás error, sin fallback automático).
  * Brave: puede intentar fallback al DNS del sistema salvo que apliques política + bloqueo 53.
  * Tor: sigue resolviendo por la red Tor (no usa DoH).

* **¿Necesito cambiar `/etc/resolv.conf` del contenedor?**
  No, si el navegador está en modo DoH-only; el sistema DNS del contenedor se ignora para navegación normal.

---

## 6) Comandos útiles (cuando sí puedas tocar config)

> Sólo referencia. Tu flujo actual no requiere instalar utilidades dentro del contenedor.

* **Brave – política DoH (Linux)**

  ```bash
  sudo mkdir -p /etc/opt/brave/policies/managed
  sudo tee /etc/opt/brave/policies/managed/doh.json > /dev/null <<'JSON'
  {
    "BuiltInDnsClientEnabled": true,
    "DnsOverHttpsMode": "secure",
    "DnsOverHttpsTemplates": "https://dns.mullvad.net/dns-query{?dns}"
  }
  JSON
  ```

* **Firefox/Mullvad – bootstrap**

  * `about:config` → `network.trr.bootstrapAddress = <IP_de_dns.mullvad.net>`

---

### Conclusión

Con **Podman rootless + slirp** y navegadores configurados en **DoH-only**,
logras que **las resoluciones DNS no dependan del contenedor** y vayan **cifradas** al proveedor elegido.
El punto crítico es el **bootstrap** del host DoH:

* **Mullvad/Firefox**: fija `network.trr.bootstrapAddress` para eliminarlo.
* **Brave**: usa política y, si quieres blindaje total, bloquea puertos 53 para impedir *fallback*.
* **Tor**: deja su resolución por Tor (no DoH) y verifica en `check.torproject.org`.
