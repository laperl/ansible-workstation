#!/usr/bin/env bash
# Bootstrap "Guru Edition" v5.0 - Pop!_OS 24.04
# Optimizado para Ansible-Core 2.20 y gestión limpia de pipx.

set -euo pipefail
IFS=$'\n\t'

# --- 1. Localización de la Raíz del Proyecto ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo -e "\033[1;34m🏠 Raíz del proyecto detectada en: $REPO_ROOT\033[0m"

# --- 2. Gestión de Limpieza y Errores ---
cleanup() {
    local exit_code=$?
    if [[ -n "${SUDO_PID:-}" ]]; then kill "$SUDO_PID" 2>/dev/null || true; fi
    [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
    if [ $exit_code -ne 0 ]; then echo -e "\n\033[0;31m[!] Proceso interrumpido.\033[0m"; fi
    exit $exit_code
}
trap cleanup EXIT ERR SIGINT SIGTERM

# --- 3. Sudo Keep-alive ---
sudo -v
(while true; do sudo -n true; sleep 60; done) 2>/dev/null &
SUDO_PID=$!

# --- 4. Herramientas del Sistema ---
echo "📦 Asegurando herramientas base (APT)..."
sudo apt-get update -qq
sudo apt-get install -y git python3 python3-venv pipx curl jq age

# --- 5. Gestión de Pipx y Ansible-Core (Modernizado) ---
export PATH="$HOME/.local/bin:$PATH"
pipx ensurepath --force >/dev/null 2>&1

# GURU CHECK: Verificar colisiones previas en pipx
if pipx list | grep -q "ansible-core"; then
    echo -e "\033[1;33m⚠️  Aviso: Se detectó una instalación existente de 'ansible-core' en pipx.\033[0m"
    read -p "¿Deseas desinstalarla para realizar una instalación limpia de la v2.20? (y/n): " clean_choice
    if [[ "$clean_choice" =~ ^[Yy]$ ]]; then
        echo "🧹 Desinstalando versión previa..."
        pipx uninstall ansible-core
    else
        echo "⏭️  Saltando instalación de Core (se usará la versión actual)."
    fi
fi

# Instalación exclusiva de la última versión estable (2.20)
if ! command -v ansible &> /dev/null; then
    echo "🐍 Instalando Ansible-Core 2.20 (Entorno exclusivo pipx)..."
    pipx install --python python3 "ansible-core~=2.20" --quiet
    pipx inject ansible-core jmespath --quiet
    echo "✅ Ansible-Core instalado correctamente."
fi

echo "🛠️ Instalando herramientas de desarrollo..."
pipx install pre-commit --quiet
# Asegurar que ansible-lint y yamllint existen globalmente (aislados)
pipx install ansible-lint
pipx install yamllint

# --- 6. SOPS (Binario verificado) ---
if ! command -v sops &> /dev/null; then
    echo "🔐 Instalando SOPS..."
    TMP_DIR=$(mktemp -d -t sops-bootstrap-XXXXXXXXXX)
    RELEASE_DATA=$(curl -sSfL https://api.github.com/repos/getsops/sops/releases/latest)
    BIN_URL=$(echo "$RELEASE_DATA" | jq -r '.assets[] | select(.name | test("linux.amd64$")) | .browser_download_url')
    SUM_URL=$(echo "$RELEASE_DATA" | jq -r '.assets[] | select(.name | endswith("checksums.txt")) | .browser_download_url')
    BIN_NAME=$(basename "$BIN_URL")

    curl -sSfL --retry 3 -o "$TMP_DIR/$BIN_NAME" "$BIN_URL"
    EXPECTED_SHA=$(curl -sSfL "$SUM_URL" | grep "$BIN_NAME" | awk '{print $1}')
    ACTUAL_SHA=$(sha256sum "$TMP_DIR/$BIN_NAME" | awk '{print $1}')

    if [[ "$EXPECTED_SHA" == "$ACTUAL_SHA" ]]; then
        chmod +x "$TMP_DIR/$BIN_NAME"
        sudo mv "$TMP_DIR/$BIN_NAME" /usr/local/bin/sops
        echo "  ✅ SOPS instalado correctamente."
    else
        echo "❌ Error de integridad en SOPS."; exit 1
    fi
fi

# --- 7. Resolución de Dependencias (requirements.yml) ---
# Limpieza de colecciones para asegurar compatibilidad con el nuevo Core y Python 3.12
[[ -d "$REPO_ROOT/collections" ]] && rm -rf "$REPO_ROOT/collections"

if [[ -f "$REPO_ROOT/requirements.yml" ]]; then
    echo "📥 Instalando colecciones frescas en $REPO_ROOT/collections..."
    "$HOME/.local/bin/ansible-galaxy" collection install -r "$REPO_ROOT/requirements.yml" -p "$REPO_ROOT/collections" --force
else
    echo "⚠️ No se encontró requirements.yml en la raíz. Instalando básicas..."
    "$HOME/.local/bin/ansible-galaxy" collection install community.general community.sops -p "$REPO_ROOT/collections"
fi

# --- 8. Lanzamiento de Ansible ---
echo -e "\033[1;32m🎨 Lanzando Playbook v2.20 desde la raíz...\033[0m"
"$HOME/.local/bin/ansible-playbook" -i inventories/local/hosts.yml site.yml -K -t base

echo -e "\n\033[1;32m✨ ¡Bootstrap completado con éxito!\033[0m"
