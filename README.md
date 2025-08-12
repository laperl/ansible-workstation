# PopOS Workstation (Ansible)

Automatiza tu estación de trabajo **Pop!OS** (Ubuntu) con Ansible: paquetes base, dotfiles con Stow, **Vim**, **tmux + TPM**, contenedores (**Podman** por defecto), gaming y tooling de IA opcional.

> Proyecto personal, durable y extensible: pensado para crecer (nuevas apps o distros) sin tocar el “core”.

---

## Requisitos

* Pop!OS / Ubuntu recién instalado (otras distros: ver *Extender a otras distros*).
* Acceso `sudo`.
* Conexión a Internet.

Todo lo utilizado (Ansible, Stow, SOPS, TPM, Podman) es **gratis**.

---

## Uso rápido (local)

```bash
# 1) Clona este repo en tu $HOME
git clone https://github.com/<tu-usuario>/ansible-workstation.git
cd ansible-workstation

# 2) Bootstrap (instala requisitos + primer playbook)
bash scripts/bootstrap.sh
```

Reaplica por áreas cuando quieras:

```bash
make base
make dev
make containers
make gaming
make ai
make security
```

---

## Uso remoto (otro PC)

1. Asegúrate de tener **SSH** al host remoto y usuario con `sudo`.
2. Edita `inventories/example/hosts.yml` y apunta a tu host.
3. Prueba ping:

```bash
ansible -i inventories/example/hosts.yml -m ping all
```

4. Ejecuta:

```bash
ansible-playbook -i inventories/example/hosts.yml site.yml -K
```

> Nota: En Pop!OS/Ubuntu Python ya viene instalado. Si no, instala `python3` primero en el remoto.

---

## Variables y opciones clave

`group_vars/all.yml` controla lo principal:

```yaml
default_editor: "vim"           # vim | nvim | vscodium
container_runtime: "podman"     # podman | docker
install_gaming: true
install_ai: true
dotfiles_packages: [bash, git, vim, tmux]
```

Cambia aquí y vuelve a ejecutar con `make` o `ansible-playbook`.

---

## Estructura del repo (resumen)

```
ansible-workstation/
├─ ansible.cfg
├─ site.yml
├─ requirements.yml
├─ inventories/
│  ├─ local/hosts.yml
│  └─ example/hosts.yml
├─ group_vars/
│  └─ all.yml
├─ roles/
│  ├─ base/        # apt/flatpak, stow, utilidades
│  ├─ devtools/    # vim, tmux+TPM, pipx, ansible-lint
│  ├─ containers/  # Podman/Docker y NVIDIA toolkit
│  ├─ gaming/      # Steam, ProtonUp-Qt, Lutris, Gamemode
│  ├─ ai/          # Toolkit NVIDIA mínimo
│  ├─ security/    # ufw, fail2ban, ssh endurecido
│  ├─ dotfiles/    # bash, git, vim, tmux
│  └─ ssh/
│     ├─ tasks/main.yml
│     └─ templates/ssh_config.j2
├─ scripts/bootstrap.sh
├─ Makefile
├─ .sops.yaml
├─ secrets/vars.sops.yaml     # (placeholder cifrado)
└─ .github/workflows/lint.yml
```

---

## Dotfiles con Stow

* Los dotfiles viven en `dotfiles/` y se linkean a `$HOME` con **GNU Stow** durante el rol `base`.
* Añade nuevas carpetas (por ejemplo `alacritty/`, `zsh/`) y súmalas a `dotfiles_packages` en `group_vars/all.yml`.

---

## tmux + TPM

* **TPM** (Tmux Plugin Manager) se instala automáticamente en `~/.tmux/plugins/tpm`.
* Para instalar los plugins declarados en `~/.tmux.conf`:

  1. Abre tmux
  2. Pulsa **Prefix + I**
* Cambia/añade plugins editando `dotfiles/tmux/.tmux.conf`.

---

## Seguridad

* `ufw` activado por defecto (deny incoming, allow outgoing) y `fail2ban`.
* `sshd` sin contraseñas (sólo clave). **Asegúrate** de tener tu clave SSH lista.

---

## Extender a otras distros

* Los roles cargan variables por familia (`roles/*/vars/Debian.yml`).
* Para otra distro, crea `roles/*/vars/RedHat.yml` (o similar), mapea los nombres de paquetes y **no toques las tareas**.
* Usa módulos agnósticos (`package`) siempre que sea posible.

---

## Añadir paquetes o apps

1. **Base/CLI**: añade en `roles/base/vars/<Familia>.yml`.
2. **Desktop**: preferible Flatpak → añade tareas `community.general.flatpak`.
3. Commits pequeños con mensajes claros (Conventional Commits): `feat(devtools): add ripgrep`.

---

## Tags útiles

* `base`, `dev`, `containers`, `gaming`, `ai`, `security`

Ejemplo:

```bash
ansible-playbook -i inventories/local/hosts.yml site.yml -K -t dev,containers
```

---

## SOPS (secretos en git)

1. Genera clave **age**:

```bash
age-keygen -o $HOME/.config/sops/age/keys.txt
```

2. Copia la pubkey (empieza por `age1`) en `.sops.yaml`.
3. Edita/crea el fichero de secretos con:

```bash
sops secrets/vars.sops.yaml
```

> Guarda aquí tokens y datos sensibles. No subas secretos en claro.

---

## CI (GitHub Actions)

* `ansible-lint` se ejecuta en cada push/PR para mantener calidad del YAML/Ansible.

---

## Troubleshooting rápido

* **Permisos sudo**: usa `-K` (pedirá password).
* **SSH host key**: el inventario de ejemplo usa `accept-new`.
* **tmux plugins**: instala dentro de tmux con **Prefix + I**.
* **GPU con Podman**: si hace falta, añade `--hooks-dir=/usr/share/containers/oci/hooks.d/` al ejecutar contenedores.

---

## Filosofía del repo

* **Core estable**: roles con tareas agnósticas; variaciones por `vars/`.
* **Ejecución por tags**: rapidez y foco.
* **Documentación viva**: este README es tu recordatorio después de meses.
