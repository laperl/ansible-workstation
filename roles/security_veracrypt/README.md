# security\_veracrypt (VeraCrypt CLI)

Rol Ansible para **instalar VeraCrypt** en Pop!\_OS/Ubuntu (paquete `.deb` verificado por **PGP**) y preparar puntos de montaje. **No** monta automáticamente: el montaje/desmontaje se hace **manual por CLI** con VeraCrypt oficial (compatible con Linux/Windows/macOS).

> **Modelo operativo**: simple, seguro y portable. Sin helpers `sudoers`, sin systemd units. El contenedor puede usarse en los tres sistemas con la misma semántica.

---

## Requisitos

* Pop!\_OS/Ubuntu 22.04/24.04 (o derivadas).
* Paquetes base (se instalan desde el rol): `gnupg`, `gpg-agent`, `ca-certificates`, `xz-utils`, `fuse3`.
* Contenedor VeraCrypt **.hc** existente (o créalo con la GUI/CLI de VeraCrypt).

> Nota: Para compatibilidad multi‑OS, el **FS interno del contenedor** suele ser **exFAT** (o NTFS) si lo vas a abrir en Windows/macOS.

---

## Variables clave

Defínelas en `group_vars/all.yml` o en `roles/security_veracrypt/defaults/main.yml`.

```yaml
# Versión fija del binario (ejemplo)
veracrypt_version: "1.26.24"
veracrypt_series:  "24.04"   # serie Ubuntu/Pop!_OS
veracrypt_arch:    "amd64"

# URLs oficiales (Downloads → Launchpad) del .deb y su firma .sig
veracrypt_deb_url: "https://launchpad.net/veracrypt/{{ veracrypt_version }}/{{ veracrypt_version }}/+download/veracrypt-{{ veracrypt_version }}-Ubuntu-{{ veracrypt_series }}-{{ veracrypt_arch }}.deb"
veracrypt_sig_url: "https://launchpad.net/veracrypt/{{ veracrypt_version }}/{{ veracrypt_version }}/+download/veracrypt-{{ veracrypt_version }}-Ubuntu-{{ veracrypt_series }}-{{ veracrypt_arch }}.deb.sig"

# Clave PGP oficial (fingerprint: 5069A233D55A0EEB174A5FC3821ACD02680D16DE)
veracrypt_pgp_key_url: "https://amcrypto.jp/VeraCrypt/VeraCrypt_PGP_public_key.asc"

# Contenedores que sueles montar
veracrypt_containers:
  - name: "personal"
    path: "{{ exfat_mountpoint }}/personal.hc"               # fichero .hc
    mount: "{{ workstation_home }}/Documents/SECURE_personal" # sin "/" final
    pim: ""  # déjalo vacío: se pedirá en runtime si procede
```

---

## Despliegue

1. **Clona/actualiza** el repo de tu *workstation*.
2. Ajusta variables arriba (si cambias de versión o rutas).
3. Ejecuta:

```bash
ansible-playbook -i inventories/local/hosts.yml site.yml -K -t veracrypt
```

El rol:

* Descarga el `.deb` y su `.sig`.
* Importa la **clave PGP** oficial en un *keyring* aislado y **verifica la firma**.
* Instala el `.deb` **solo si** la versión difiere (idempotente).
* Crea los directorios `mount` con **0700**.

> **Actualizaciones**: he configurado un **Watch → Releases** en el GitHub de VeraCrypt para enterarme de nuevas versiones. Cuando haya una nueva: cambia `veracrypt_version`/`*_url` y vuelve a ejecutar el rol.

---

## Uso (montaje/desmontaje manual, CLI)

### Montar (pedirá **contraseña** y, si aplica, **PIM**)

```bash
# monta en el destino indicado
veracrypt --text --mount /ruta/al/contenedor.hc /ruta/al/mountpoint

# ejemplo con tus rutas típicas
veracrypt --text --mount \
  "$HOME/Documents/CONTENEDOR/personal.hc" \
  "$HOME/Documents/SECURE_personal"
```

### Desmontar

```bash
# desmontar un volumen concreto
veracrypt -d "$HOME/Documents/SECURE_personal"

# o desmontar todos los volúmenes montados por VeraCrypt
veracrypt -d
```

### Opcional (avanzado)

* Si usas PIM conocido y no quieres que lo pregunte, puedes pasarlo explícitamente:

```bash
veracrypt --text --pim 123 --mount /ruta/contenedor.hc /ruta/mountpoint
```

> **Recomendación**: evita pasar contraseña en flags/argv. Deja que VeraCrypt la pida en el prompt.

---

## Buenas prácticas

* **No almacenes** contraseña ni PIM en texto plano ni en variables de entorno.
* Usa puntos de montaje con permisos **0700**.
* Comprueba qué hay montado:

```bash
veracrypt -l
```

* Antes de desconectar el disco o apagar, **desmonta**: `veracrypt -d <mount>`.
* Copias de seguridad: conserva el contenedor `.hc` y (si procede) un **header backup**.
* Si el contenedor se usa en varios OS, formatea su FS interno como **exFAT**/NTFS.
* Verifica **firmas PGP** del `.deb` y valida el **fingerprint** de la clave.

---

## Solución de problemas

* **"device is busy" al desmontar**: cierra procesos/terminales en el `mountpoint`.

  * Ayudas: `lsof +D <mount>` o `fuser -vm <mount>`.
* **Permisos denegados**: asegúrate de que `fuse3` está instalado y de montar en un directorio propio.
* **Ruta incorrecta**: verifica que `path` apunta a un **fichero `.hc`** existente y que el disco base (exFAT) está montado.

---

## Notas de seguridad

* Fingerprint de la clave PGP de VeraCrypt (actual):

  `5069A233D55A0EEB174A5FC3821ACD02680D16DE`

* Pasos típicos de verificación (resumen):

  1. Descargar la clave pública y **comprobar el fingerprint**.
  2. Importarla al *keyring* y **confiarla**.
  3. Verificar `.sig` contra el `.deb` descargado.

> El rol automatiza estos pasos, pero conviene conocerlos y revisarlos si cambias de fuente.

---

## Ejemplos rápidos

```bash
# montar con directorio por defecto (crear y proteger)
mkdir -p "$HOME/Documents/SECURE_personal" && chmod 700 "$HOME/Documents/SECURE_personal"
veracrypt --text --mount "$HOME/Documents/CONTENEDOR/personal.hc" "$HOME/Documents/SECURE_personal"

# listar
veracrypt -l

# desmontar
veracrypt -d "$HOME/Documents/SECURE_personal"
```

---

## Mantenimiento

* **Actualizar versión**: cambia `veracrypt_version` y URLs → vuelve a ejecutar el rol.
* **Nuevos contenedores**: añade entradas en `veracrypt_containers` para que el rol cree los puntos de montaje (no los monta).
* **Watch** en GitHub de VeraCrypt para estar al día de **releases** y **avisos**.

---

## Scope del rol

* **Incluye**: instalación verificada del binario, creación de directorios seguros.
* **Excluye (a propósito)**: auto‑montaje, helpers `sudoers`, units systemd. El montaje es manual por CLI para máxima portabilidad y control.
