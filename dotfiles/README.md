# 📂 Dotfiles

Este directorio contiene todos los paquetes de dotfiles gestionados por **GNU Stow**.

## Estructura
Cada subdirectorio aquí es un *paquete*:
- `bash/` → ficheros `.bashrc`, `.bash_aliases`
- `git/` → configuración de Git (`.gitconfig`)
- `htop/` → configuración de htop (`.config/htop/htoprc`)
- `tmux/` → `.tmux.conf`
- `vim/` → `.vimrc`

La estructura interna de cada paquete debe **replicar la jerarquía de `$HOME`**.
Ejemplo: `dotfiles/htop/.config/htop/htoprc` → enlazará a `~/.config/htop/htoprc`.

## Variables de Ansible
El rol `base` usa la variable `dotfiles_packages` para decidir qué paquetes aplicar.
Está definida en `group_vars/all/all.sops.yml`.

👉 **Cuando añadas un paquete nuevo** (ej. `zsh`):
1. Crea `dotfiles/zsh/` con los ficheros.
2. Añade `zsh` a la lista `dotfiles_packages` en `group_vars/all/all.sops.yml` (recuerda descifrar y volver a cifrar con SOPS).
3. Vuelve a ejecutar el playbook.

## Tips
- Haz `stow -nvt ~ <paquete>` para probar sin aplicar.
- Copias de seguridad de ficheros en conflicto se guardan en `~/dotfiles-backup/`.

### Caso especial: htop (sin Stow)

`htop` sobrescribe `~/.config/htop/htoprc` al guardar cambios y puede reemplazar un symlink con un write+rename.
Para evitar que rompa el enlace y, de paso, que el repo se modifique:

- **No** stoweamos `htoprc`.
- Lo desplegamos con Ansible desde `roles/base/files/htop/htoprc` mediante **copia** (no symlink).
- Permisos destino: `0664` (el usuario puede editar; el repo no se toca).

> Si añades `htop` como paquete en `dotfiles/`, retíralo de `dotfiles_packages` (en `group_vars/all/all.sops.yml`) para que Stow no lo gestione.
