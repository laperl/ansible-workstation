#!/usr/bin/env bash
# Bootstrap del playbook en Pop!_OS/Ubuntu (robusto, idempotente)
set -euo pipefail
IFS=$'\n\t'

# Log básico en caso de error
trap 'echo "[!] Error en línea $LINENO"; exit 1' ERR

# 0) Sudo al día
if ! sudo -v; then echo "Necesitas sudo." >&2; exit 1; fi

# 1) Paquetes base (git, make, pipx, cifrado, stow, flatpak)
sudo apt-get update -y
sudo apt-get install -y git make python3 python3-venv pipx age gnupg stow flatpak

# 2) Asegura PATH para pipx (~/.local/bin) sin interrumpir si ya está
pipx ensurepath >/dev/null 2>&1 || true

# 3) Elegir intérprete Python para herramientas (preferimos 3.12>3.11>3.x)
choose_python() {
  command -v python3.12 >/dev/null 2>&1 && { echo "python3.12"; return; }
  command -v python3.11 >/dev/null 2>&1 && { echo "python3.11"; return; }
  echo "python3"
}
PYBIN="$(choose_python)"

# 4) Helpers
has_bin() { command -v "$1" >/dev/null 2>&1; }             # ¿existe binario en PATH?
py_is_ge_311() { "$PYBIN" - <<'PY'
import sys; import sys
sys.exit(0 if sys.version_info[:2] >= (3,11) else 1)
PY
}

# 5) Instalar herramientas con series fijadas (sólo si faltan)
#    - ansible-core 2.18.x si Python>=3.11; si no, 2.17.x (compatible 3.10)
if ! has_bin ansible-playbook; then
  if py_is_ge_311; then
    pipx install --python "$PYBIN" "ansible-core~=2.18"
  else
    pipx install --python "$PYBIN" "ansible-core~=2.17"
  fi
fi

has_bin ansible-lint || pipx install --python "$PYBIN" "ansible-lint~=25.7"
has_bin yamllint     || pipx install --python "$PYBIN" "yamllint~=1.37"
# 5b) Inyectar dependencias Python requeridas por filtros (json_query -> jmespath)
#     Esto instala jmespath dentro del venv de pipx de ansible-core.
pipx inject ansible-core jmespath

# (Opcional) Verificar que quedó instalado en ese venv
pipx runpip ansible-core show jmespath || true

# 6) Colecciones Galaxy (si las declaras en requirements.yml)
if [ -f requirements.yml ]; then
  ansible-galaxy collection install -r requirements.yml
fi

# 7) pre-commit (opcional pero recomendado, sólo si el repo lo define)
if [ -d ".git" ] && [ -f ".pre-commit-config.yaml" ]; then
  has_bin pre-commit || pipx install --python "$PYBIN" pre-commit
  pre-commit install                              # activa hooks en este repo
  # pre-commit run --all-files || true            # primera pasada (opcional)
fi

# 8) Primer run por áreas seguras
#ansible-playbook -i inventories/local/hosts.yml site.yml -K -t base,dev
ansible-playbook -i inventories/local/hosts.yml site.yml -K -t base

