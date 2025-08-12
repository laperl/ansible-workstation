# Gestión de clave SSH y ssh-agent (Pop!\_OS)

Guía práctica para **usar una única clave SSH con passphrase** tanto para GitHub como para acceso a máquinas, desplegándola con Ansible desde ficheros **cifrados con SOPS** y cargándola automáticamente con **ssh-agent** (vía `keychain`).

> Este documento está pensado para que lo puedas seguir incluso meses después sin recordar detalles.

---

## 1) Crear o reutilizar la clave SSH

Si ya tienes una clave con passphrase, salta al punto 2. Para crear una nueva (recomendado `ed25519`):

```bash
ssh-keygen -t ed25519 -a 100 -C "pops@popos-workstation" -f ~/.ssh/id_ed25519
# -a 100 endurece con más rondas de KDF (bcrypt)
```

**Sube la pública a GitHub**: Settings ➜ SSH and GPG keys ➜ *New SSH key* (pega el contenido de `~/.ssh/id_ed25519.pub`).

> Buenas prácticas: idealmente usa **claves diferentes** para GitHub y para acceso a servidores. Si decides reutilizar la misma, comprendes el riesgo y aceptas el trade-off de simplicidad.

---

## 2) Cifrar la clave con SOPS (age)

1. Asegúrate de tener clave **age** local (para SOPS):

```bash
age-keygen -o $HOME/.config/sops/age/keys.txt
```

2. Añade tu **clave pública age** (la que empieza por `age1...`) en `.sops.yaml` del repo.

3. Cifra la clave privada **en binario** y guarda el resultado en el repo:

```bash
# Desde la raíz del repo
mkdir -p secrets/ssh
sops -e --input-type binary --output-type binary \
  ~/.ssh/id_ed25519 > secrets/ssh/id_ed25519.sops

# Copia la pública (no hace falta cifrarla):
cp ~/.ssh/id_ed25519.pub secrets/ssh/id_ed25519.pub
```

> Nunca subas `~/.ssh/id_ed25519` en claro al repo. Sólo el `.sops` cifrado.

---

## 3) Despliegue con Ansible

El rol `ssh`:

* Crea `~/.ssh` con permisos correctos.
* Desencripta `secrets/ssh/id_ed25519.sops` en `~/.ssh/id_ed25519` (600).
* Copia la pública a `~/.ssh/id_ed25519.pub` (644).
* Escribe `~/.ssh/config` con reglas para GitHub y hosts.
* Añade `github.com` a `known_hosts` de forma automática.
* Configura `keychain` para cargar la clave en `ssh-agent` al iniciar sesión.

Ejecución típica:

```bash
# Ejecución sólo del rol ssh
ansible-playbook -i inventories/local/hosts.yml site.yml -K -t ssh
```

> **Nota de seguridad**: Ansible marcará las tareas sensibles como `no_log: true` para no volcar la clave en la salida.

---

## 4) Carga automática con ssh-agent (keychain)

Se añade este bloque a `~/.bashrc`:

```bash
if command -v keychain >/dev/null 2>&1; then
  eval "$(keychain --quiet --agents ssh --eval --timeout 43200 ~/.ssh/id_ed25519)"
fi
```

* Pide la passphrase **una vez por sesión** (o hasta 12h).
* Funciona en TTY, terminal gráfica y dentro de **tmux**.
* Asegúrate de que tu `~/.tmux.conf` tenga:

```tmux
set -g update-environment "SSH_AUTH_SOCK DISPLAY"
```

> Alternativa en entorno gráfico: GNOME Keyring puede recordar la passphrase y desbloquearla al iniciar sesión.

---

## 5) Archivo `~/.ssh/config` generado

```sshconfig
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  AddKeysToAgent yes

Host *
  ServerAliveInterval 60
  ServerAliveCountMax 3
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  AddKeysToAgent yes
```

> Para hosts concretos añade bloques adicionales con `Host ws01` etc.

---

## 6) Añadir `known_hosts` de GitHub

Se realiza automáticamente con:

```bash
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
```

En Ansible se usa el módulo `known_hosts` para hacerlo idempotente.

---

## 7) Comprobaciones rápidas

```bash
# ¿Está la clave cargada en el agente?
ssh-add -l

# Probar acceso a GitHub por SSH (sin clonar)
ssh -T git@github.com

# Depuración si algo falla (verbosidad)
GIT_SSH_COMMAND="ssh -vvv" git ls-remote git@github.com:<user>/<repo>.git
```

---

## 8) Rotación y copia de seguridad

* **Rotación**: genera nueva clave, actualiza GitHub/servidores y reemplaza `secrets/ssh/id_ed25519.sops` con la nueva (PR separado).
* **Backup**: guarda la clave **en un gestor seguro** (p.ej., KeePassXC) y conserva tu `keys.txt` de age offline.
* **Múltiples máquinas**: añade **múltiples recipients age** en `.sops.yaml` para que cualquiera de tus controladores pueda descifrar.

---

## 9) Riesgos y mitigaciones

* **Riesgo**: la clave privada viaja cifrada en el repo.

  * **Mitiga**: passphrase fuerte, recipients age mínimos, `no_log` en Ansible, permisos 600, y considera separar claves (GitHub ⇄ servidores).
* **Robo del portátil**: sin `keys.txt` de age y sin passphrase, no podrán descifrar; aun así, cifra el disco (LUKS) y usa login seguro.

---

## 10) Apéndice: comandos útiles

```bash
# Volver a cifrar (reencrypt) con nuevos recipients age
sops -r -i secrets/ssh/id_ed25519.sops

# Forzar pedir passphrase de nuevo (vaciar agente)
ssh-add -D

# Ver socket del agente
echo $SSH_AUTH_SOCK
```

