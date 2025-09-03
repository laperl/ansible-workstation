# SOPS — Guía rápida para este repositorio

> Cómo **instalar**, **editar**, **cifrar** y **descifrar** secretos con SOPS (Age/PGP), aplicado a tus ficheros en `secrets/`.

---

## 1) Qué es SOPS

SOPS es un editor de ficheros **cifrados** que soporta YAML/JSON/ENV/INI (y binarios). Cifra **valores** manteniendo las **claves** legibles (en YAML/JSON), y usa proveedores de claves como **age**, **PGP** o KMS (AWS/GCP/Azure). En este repo lo usamos para almacenar de forma segura los `.conf` de Proton (WireGuard) y otros secretos.

---

## 2) Instalación en Pop!\_OS / Ubuntu

1. Descarga el `.deb` estable desde *Releases* de SOPS.
2. Instala:

   ```bash
   sudo dpkg -i ~/Descargas/sops_*.deb || sudo apt -f install
   sops --version
   ```

> Alternativa: empaquetados de terceros (p. ej. repos WakeMeOps) si prefieres `apt install sops`.

---

## 3) Claves (recomendado: **age**)

### 3.1 Genera tu identidad age y configúralo

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
# (opcional) export explícito si usas otra ruta
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

* **Copia de seguridad**: guarda `keys.txt` en lugar seguro (tu bóveda). Sin esa clave no podrás descifrar.
* Tus **recipients** (públicos) comienzan por `age1...` y están en `keys.txt`.

### 3.2 PGP (alternativa)

Importa tu llave PGP y referencia su **fingerprint** en `.sops.yaml` si prefieres PGP. No mezcles métodos sin necesidad.

---

## 4) `.sops.yaml` del repo (ya incluido)

* Define **qué claves** (age/PGP/KMS) se usan al **crear/editar** ficheros bajo `secrets/` (y patrones).
* Por eso normalmente **no necesitas** pasar `--age`/`--pgp`: con estar en el repo, SOPS detecta la config y aplica las claves correctas.

> Si mueves un secreto fuera del árbol del repo, usa `--config .sops.yaml` o vuelve a la raíz del repo al ejecutar SOPS.

---

## 5) Flujos típicos

### 5.1 Crear o **editar** un secreto (modo interactivo)

```bash
# EDITOR respeta $EDITOR o $SOPS_EDITOR (nano, vim, etc.)
EDITOR=nano sops secrets/wg-protonvpn/proton.conf.sops.yaml
```

* Si el fichero **no existe**, SOPS lo crea ya cifrado.
* Si **existe**, lo abre **en claro** en tu editor; al cerrar, lo guarda **cifrado**.

### 5.2 **Descifrar** a stdout o a fichero

```bash
# ver en consola (no deja rastro en disco)
sops -d secrets/wg-protonvpn/proton.conf.sops.yaml

# sobrescribir en claro (⚠️ no lo subas a git)
cp secrets/wg-protonvpn/proton.conf.sops.yaml /tmp/proton.yaml
sops -d -i /tmp/proton.yaml
```

### 5.3 **Cifrar** un fichero claro existente

```bash
# crea un fichero cifrado nuevo sin tocar el original
sops -e --output secrets/wg-protonvpn/proton.conf.sops.yaml /ruta/mi_conf.yaml

# cifrado en sitio (in-place)
sops -e -i /ruta/mi_conf.yaml   # ⚠️ se pierde la versión en claro
```

### 5.4 **Extraer** solo una clave de un YAML cifrado

Si guardas tu `.conf` dentro de un YAML bajo la clave `wg_conf` (recomendado), puedes extraerlo así:

```bash
sops -d --extract '["wg_conf"]' secrets/wg-protonvpn/proton.conf.sops.yaml
```

### 5.5 Rotar/actualizar **recipients** (cambio de claves)

```bash
# sincroniza recipients definidos en .sops.yaml (añade/quita claves)
sops updatekeys secrets/wg-protonvpn/proton.conf.sops.yaml

# rotación de la data key conservando recipients
sops -r -i secrets/wg-protonvpn/proton.conf.sops.yaml
```

---

## 6) Formatos de secreto admitidos en este repo

Tienes **dos opciones** (ambas soportadas por el role):

### Opción A — YAML con la clave `wg_conf` (recomendada)

Ventajas: más claro para comentarios, y permite añadir metadatos si algún día hace falta.

```yaml
# secrets/wg-protonvpn/proton.conf.sops.yaml (cifrado con SOPS)
wg_conf: |
  [Interface]
  PrivateKey = <tu_privada>
  Address = 10.2.0.2/32
  DNS = 10.2.0.1

  [Peer]
  PublicKey = <publica_del_servidor>
  AllowedIPs = 0.0.0.0/0, ::/0
  Endpoint = es-xx.protonvpn.net:51820
  PersistentKeepalive = 25
```

### Opción B — `.conf` plano cifrado

Guarda el `.conf` tal cual (texto) y cífralo con SOPS.

```bash
sops -e --output secrets/wg-protonvpn/proton-vpn.conf.sops.conf /ruta/proton-vpn.conf
# o edítalo directamente
sops secrets/wg-protonvpn/proton-vpn.conf.sops.conf
```

> El role detecta el tipo y hará `wg-quick strip`, extraerá `Address`/`DNS` y generará la `*.purowg.conf` necesaria para `wg setconf`.

---

## 7) Buenas prácticas

* **Nunca** subas a git un fichero **descifrado**. Usa stdout o `/tmp` y bórralo después.
* **Copia de seguridad** de `~/.config/sops/age/keys.txt` (y, si usas PGP, de tus llaves y revocation cert).
* Usa ramas/PRs y revisa diffs: SOPS deja las **claves** visibles y cifra los **valores**.

---

## 8) Comandos rápidos (chuleta)

```bash
# Editar/crear
sops secrets/.../archivo.sops.yaml

# Descifrar (stdout)
sops -d secrets/.../archivo.sops.yaml

# Cifrar (in-place)
sops -e -i secrets/.../archivo.yaml

# Extraer clave YAML
sops -d --extract '["wg_conf"]' secrets/.../archivo.sops.yaml

# Rotar data key
sops -r -i secrets/.../archivo.sops.yaml

# Sincronizar recipients según .sops.yaml
sops updatekeys secrets/.../archivo.sops.yaml
```

---

## 9) Problemas comunes

* **"no identity found"**: SOPS no encuentra tus claves age. Verifica `~/.config/sops/age/keys.txt` o exporta `SOPS_AGE_KEY_FILE`.
* **GUI editor** no guarda: algunos editores no bloquean el proceso; usa `SOPS_EDITOR` o un editor que espere (nano/vim).
* **.sops.yaml** no se aplica: ejecuta SOPS **desde la raíz** del repo o usa `--config .sops.yaml`.
