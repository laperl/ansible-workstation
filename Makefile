.PHONY: help
help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	awk 'BEGIN {FS=":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

base: ## Paquetes base + dotfiles
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t base

dev: ## Neovim/Vim, VSCodium, pipx, tmux
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t dev

containers: ## Podman/Docker (+ NVIDIA si procede)
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t containers

gaming: ## Steam/Proton/Lutris/Gamemode
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t gaming

ai: ## Tooling IA mínimo NVIDIA
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t ai

security: ## ufw/fail2ban/sshd endurecido
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t security

