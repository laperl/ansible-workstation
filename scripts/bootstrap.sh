#!/usr/bin/env bash
# Bootstrap para Pop!_OS/Ubuntu recien instalado.
# - Instala dependencias básicas para ejecutar Ansible
# - Clona collections y ejecuta el playbook local
set -euo pipefail

sudo apt update
sudo apt install -y git curl gpg age ansible python3-venv pipx stow flatpak

# Flathub (idempotente)
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Collections Ansible
echo "Instalando lo que hay en 'requerimets.yml'"
ansible-galaxy collection install -r requirements.yml

# Primera ejecución local
echo "Ejecutando playbook 'site.yml'"
ansible-playbook -i inventories/local/hosts.yml site.yml -K

echo "✅ Bootstrap listo. Reejecuta con 'make <tag>' para áreas concretas."
