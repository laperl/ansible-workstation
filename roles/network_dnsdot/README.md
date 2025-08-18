# Rol: network\_dnsdot

Este rol configura **DNS-over-TLS (DoT)** en Pop!\_OS/Ubuntu, permitiendo que todas las consultas DNS se realicen de forma **cifrada y segura** hacia el proveedor seleccionado.

---

## Variables principales

El proveedor lo podemos escoger en `group_vars/all.yml`.

* **`network_dnsdot_provider`**
  Proveedor de DNS por defecto. Valores soportados:

  * `cloudflare`
  * `quad9`
  * `nextdns`

* **`network_dnsdot_providers`**
  Diccionario con la lista de servidores (IPv4/IPv6) y servidores de *fallback* para cada proveedor.

Ejemplo (desde `defaults/main.yml`):

```yaml
network_dnsdot_provider: "cloudflare"

network_dnsdot_providers:
  cloudflare:
    servers:
      - 1.1.1.1#one.one.one.one
      - 1.0.0.1#one.one.one.one
    fallback:
      - 9.9.9.9#dns.quad9.net
```

---

## Comportamiento del rol

1. Configura **systemd-resolved** para usar DNS-over-TLS.
2. Aplica el proveedor definido en `network_dnsdot_provider`.
3. Si el servidor principal no responde, se usan los *fallbacks* definidos.
4. Todas las consultas DNS salen cifradas hacia el servidor indicado (`#hostname`).

---

## Verificación del estado

### Ver servidor activo

```bash
systemd-resolve --status | grep 'DNS Servers' -A2
```

### Ver resolución de un dominio

```bash
dig @127.0.0.53 example.com
```

### Comprobar DoT en uso (cifrado)

```bash
sudo journalctl -u systemd-resolved | grep -i tls
```

### Consultar a qué servidor van las peticiones

```bash
resolvectl dns
resolvectl statistics
```

---

## Buenas prácticas

* Cambiar `network_dnsdot_provider` en `group_vars/` o `host_vars/` según el host.
* Usar `quad9` si buscas más foco en **bloqueo de malware/phishing**.
* Usar `cloudflare` si priorizas **velocidad y privacidad**.
* Usar `nextdns` si quieres **filtros personalizados** (requiere cuenta/configuración previa).

---

## Recursos

* [systemd-resolved manpage](https://www.freedesktop.org/software/systemd/man/resolved.conf.html)
* [DNS Privacy (DNS-over-TLS)](https://dnsprivacy.org/)

