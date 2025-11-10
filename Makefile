.PHONY: help
help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	awk 'BEGIN {FS=":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

base: ## Paquetes base + dotfiles
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t base

dev: ## Neovim/Vim, VSCodium, pipx, tmux
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t dev

containers: ## Podman/Docker (+ NVIDIA si procede) (DEV NO USAR)
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t containers

gaming: ## Steam/Proton/Lutris/Gamemode
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t gaming

ai: ## Tooling IA mínimo NVIDIA (DEV NO USAR)
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t ai

security: ## ufw/fail2ban/sshd endurecido (DEV NO USAR)
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t security

exfat: ## Configura/actualiza el punto de montaje exFAT (fstab + automount)
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t exfat

veracrypt: ## Instala/usa VeraCrypt; depende de exfat (la dependencia la tiene en cuenta ansible
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t veracrypt

dns: ## Instala DNS DoT (DNS over TLS)
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t dns,dot

vpn: ## Instala wireguard para usar la VPN de protonvpn
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t vpn,wg

network: ## Instala "dns", "vpn"
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t network

pipeviewer: ## Instala "pipeviewer", "yt-dlp" dentro de podman para ver videos de youtube
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t pipeviewer

persona: ## Instala navegadors per les diferents persones digitals.
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t personas
