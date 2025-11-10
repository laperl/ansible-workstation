# PopOS Workstation (Ansible)

Automatiza tu estación de trabajo **Pop!OS** (Ubuntu) con Ansible: paquetes base, dotfiles con Stow, **Neovim (CLI)**, **VSCodium (GUI)**, **tmux + TPM**, contenedores (**Podman** por defecto), gaming y tooling de IA opcional.

> Proyecto personal, durable y extensible: pensado para crecer (nuevas apps o distros) sin tocar el “core”.

---

## Requisitos

* Pop!OS / Ubuntu recién instalado (otras distros: ver *Extender a otras distros*).
* Acceso `sudo`.
* Conexión a Internet.
* IMPORTANTE: No instalar ansible con apt, luego lo hará automáticamente el **bootstrap.bash**

Todo lo utilizado (Ansible, Stow, SOPS, TPM, Podman) es **gratis**.

---

## Uso rápido (local)

### Prerrequisitos

Instalar pops como indico en el archivo: `docs/sops_uso.md`

```bash
# 1) Clona este repo en tu $HOME
git clone https://github.com/<tu-usuario>/popos-workstation-ansible.git
cd popos-workstation-ansible

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
# Usuario destino y HOME (instalación en su $HOME aunque uses sudo)
workstation_facts_user: "{{ ansible_env.SUDO_USER | default(ansible_user_id) }}"
workstation_facts_home: "{{ '/root' if workstation_facts_user == 'root' else '/home/' + workstation_facts_user }}"

# Editor CLI (por defecto Neovim)
cli_editor: "nvim"            # nvim | vim

# Editor GUI (por defecto VSCodium por Flatpak)
install_vscodium: true
vscodium_flatpak_id: "com.vscodium.codium"

# Contenedores y extras
container_runtime: "podman"   # podman | docker
install_gaming: true
install_ai: true

# Dotfiles que Stow enlaza al $HOME
# Añade "nvim" si más adelante incluyes ~/.config/nvim
dotfiles_packages: [bash, git, vim, tmux]
```

Cambia aquí y vuelve a ejecutar con `make` o `ansible-playbook`.

---

## Usuario objetivo (HOME correcto con sudo)

Cuando el play se ejecuta con `become: true`, los *facts* pueden apuntar a `/root`. Para que los roles escriban siempre en el **HOME del usuario real**, el play resuelve `workstation_facts_user` y `workstation_facts_home` al inicio:

```yaml
# site.yml (extracto)
pre_tasks:
  - name: Resolver usuario efectivo
    set_fact:
      workstation_facts_user: "{{ workstation_facts_user | default(ansible_env.SUDO_USER | default(ansible_user_id)) }}"

  - name: HOME del usuario por getent
    command: "getent passwd {{ workstation_facts_user }}"
    register: pw
    changed_when: false

  - name: Fijar workstation_facts_home
    set_fact:
      workstation_facts_home: "{{ (pw.stdout.split(':'))[5] }}"
```

> Los roles usan `workstation_facts_home` en todas las tareas de usuario y esas tareas llevan `become: false`.

**Comprobación rápida**:

```bash
echo "user=$workstation_facts_user home=$workstation_facts_home"
test -d "$workstation_facts_home/.local/bin" || echo "se creará en devtools"
```

---

## Editor (CLI/GUI): Neovim + VSCodium

(CLI/GUI): Neovim + VSCodium

* `cli_editor`: elige `nvim` o `vim` (por defecto `nvim`).
* Si `cli_editor: nvim`:

  * Se crean symlinks en `~/.local/bin`: `vim` y `vi` → `/usr/bin/nvim`.
  * Se añaden alias de respaldo en `~/.bash_aliases` (`vim`/`vi` → `nvim`).
  * `EDITOR` y `VISUAL` se exportan a `nvim` en `~/.bashrc`.
  * En Debian/Ubuntu se configura `update-alternatives`: `/usr/bin/editor` → `nvim`.
* `install_vscodium: true` instala **VSCodium** por Flatpak (`com.vscodium.codium`) y crea un wrapper en `~/.local/bin/codium` que ejecuta `flatpak run com.vscodium.codium`.
* **Verificación rápida**:

```bash
which nvim vim vi codium
echo $EDITOR
editor --version | head -1
```

---

## Estructura del repo (resumen)

```
popos-workstation-ansible/
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
│  ├─ devtools/    # nvim/vim, VSCodium, pipx, ansible-lint, tmux+TPM
│  ├─ containers/  # Podman/Docker y NVIDIA toolkit
│  ├─ gaming/      # Steam, ProtonUp-Qt, Lutris, Gamemode
│  ├─ ai/          # Toolkit NVIDIA mínimo
│  └─ security/    # ufw, fail2ban, ssh endurecido
├─ dotfiles/       # bash, git, vim, tmux (añade nvim si lo usas)
├─ scripts/bootstrap.sh
├─ Makefile
├─ .sops.yaml
├─ secrets/vars.sops.yaml
└─ .github/workflows/lint.yml
```

---

## Dotfiles con Stow

* Los dotfiles viven en `dotfiles/` y se linkean a `$HOME` con **GNU Stow** durante el rol `base`.
* Añade nuevas carpetas (por ejemplo `alacritty/`, `zsh/`, `nvim/`) y súmalas a `dotfiles_packages` en `group_vars/all.yml`.
* Si usas Neovim con configuración propia, crea `dotfiles/nvim/.config/nvim/` y añade `nvim` a `dotfiles_packages`.

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

## Roles adicionales

- **mm_media (pipe‑viewer)**: despliega pipe‑viewer sin anuncios en un contenedor Podman rootless. Consulta [roles/mm_media/README.md](roles/mm_media/README.md) para más detalles.
  La guía ampliada y las consideraciones de seguridad están en `docs/mm_media_pipeviewer.md` y `docs/mm_media_security.md`.

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
