# Rol: `storage_exfat`

Configura un punto de montaje **exFAT** estable para alojar contenedores VeraCrypt (u otros datos) en Pop!\_OS/Ubuntu. El rol crea el directorio de montaje, asegura una entrada en `/etc/fstab` con **PARTUUID=** o **LABEL=** o **UUID=** y habilita **automontaje bajo demanda** con `x-systemd.automount`, aplicando opciones de hardening (`nosuid,nodev,noexec`).

---

## Objetivos

* Montaje **reproducible e idempotente** usando `ansible.posix.mount`.
* Soporte para discos intercambiables (recomendada `LABEL=` única).
* Automontaje bajo demanda (systemd) y no fallo si el disco no está (`nofail`).
* Máscara de permisos para exFAT mediante `uid/gid,fmask,dmask`.

---

## Requisitos

* Sistema base Pop!\_OS/Ubuntu.
* El volumen exFAT existe y está **etiquetado** (p. ej. `CONTENEDOR`) o conoces su **UUID**.
* La colección `ansible.posix` disponible en el *controller* (se instala con `ansible-galaxy collection install ansible.posix`).

> Nota: exFAT no implementa permisos POSIX; se emulan con `uid/gid,fmask,dmask` en el montaje. En este caso, el directorio se montará como root pero el usuario podrá hacer CRUD dentro por el efecto de los 'fmask y dmask'.

---

## Variables (en `group_vars/all.yml`)

```yaml
defaults:
  # Dónde montar el disco exFAT
  exfat_mountpoint: "{{ workstation_home }}/Documents/CONTENEDOR"
  exfat_fstype: "exfat"

  # Identificador del volumen. Elige **uno**:
  exfat_src: "LABEL=CONTENEDOR"     # Recomendado: etiqueta única y constante
  # exfat_src: "UUID=XXXX-XXXX"     # Alternativa: usa UUID real

  # Propietario efectivo al montar exFAT (uid/gid del usuario real)
  # Se resuelven automáticamente con getent
  exfat_uid: "{{ getent_passwd[workstation_user][1] | default(omit) }}"
  exfat_gid: "{{ getent_passwd[workstation_user][2] | default(omit) }}"

  # Opciones de montaje seguras/prácticas
  exfat_opts: >-
    uid={{ exfat_uid }},gid={{ exfat_gid }},
    fmask=0177,dmask=0077,
    nosuid,nodev,noexec,noatime,
    x-systemd.automount,x-systemd.idle-timeout=60,
    nofail
```

**Notas**

* `LABEL=` facilita cambiar de disco: basta replicar la etiqueta.
* `fmask=0177,dmask=0077` ocultan el bit de ejecución en ficheros y limitan lectura a tu usuario.
* `x-systemd.automount` crea una *automount unit* y sólo monta al acceder al path; `nofail` evita bloquear el arranque.

---

## Tareas principales (resumen)

```yaml
- name: Resolver UID/GID del usuario con getent
  ansible.builtin.getent:
    database: passwd
    key: "{{ workstation_user }}"

- name: Crear punto de montaje exFAT
  ansible.builtin.file:
    path: "{{ exfat_mountpoint }}"
    state: directory
    owner: "{{ workstation_user }}"
    group: "{{ workstation_user }}"
    mode: '0755'
  become: true

- name: Asegurar entrada en fstab
  ansible.posix.mount:
    path: "{{ exfat_mountpoint }}"
    src:  "{{ exfat_src }}"
    fstype: "{{ exfat_fstype }}"
    opts: "{{ exfat_opts }}"
    state: present
  become: true

- name: Recargar systemd (automount)
  ansible.builtin.command: systemctl daemon-reload
  changed_when: false
  become: true
```

---

## Integración: ejecutar *antes* de `security_veracrypt`

Para garantizar que el punto de montaje exista **siempre** antes de manejar contenedores VeraCrypt, declara una **dependencia de rol** en `roles/security_veracrypt/meta/main.yml`:

```yaml
---
dependencies:
  - role: storage_exfat
    tags: ['always']
```

> Con `tags: ['always']`, esta dependencia correrá incluso si ejecutas `--tags veracrypt`.

---

## Cómo obtener **UUID** o fijar **LABEL** del volumen

### Ver LABEL/UUID actuales

```bash
lsblk -f   # columnas NAME,FSTYPE,LABEL,UUID,MOUNTPOINT
# o
sudo blkid
```

### Asignar/cambiar LABEL (recomendado para discos intercambiables)

```bash
# Requiere exfatprogs; el volumen NO debe estar montado
sudo exfatlabel /dev/sdX1 CONTENEDOR
```

### Usar LABEL en `group_vars/all.yml`

```yaml
exfat_src: "LABEL=CONTENEDOR"
```

### Usar UUID en `group_vars/all.yml`

```yaml
exfat_src: "UUID=XXXX-XXXX"  # reemplaza por el UUID real mostrado por lsblk/blkid
```

---

## Ejecución del rol (opcional, aislado)

Si quieres ejecutar sólo este rol:

```bash
ansible-playbook -i inventories/local/hosts.yml site.yml -K --tags exfat
```

---

## Notas de seguridad

* Mantén `nosuid,nodev,noexec` en volúmenes exFAT con datos descargables.
* Directorios necesitan bit **x**: usa `0755` (o `0700` si sólo tu usuario accederá).
* Evita rutas montadas world-writable.

---

## Solución de problemas

* **No se monta al acceder:** revisa `systemctl daemon-reload` tras cambiar `fstab` y el uso de `x-systemd.automount`.
* **Fallo por disco ausente:** confirma la presencia de `nofail` en `exfat_opts`.
* **Permisos raros en exFAT:** ajusta `uid/gid` (usuario propietario) y `fmask/dmask`.
