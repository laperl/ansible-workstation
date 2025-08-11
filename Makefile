help:           ## Mostrar ayuda de comandos
	@grep -E '^[a-zA-Z_-]+:.*?## ' Makefile | sed 's/:.*##/: /'

bootstrap:      ## Instalar collections y ejecutar playbook local
	ansible-galaxy collection install -r requirements.yml
	ansible-playbook -i inventories/local/hosts.yml site.yml -K

base:           ## Solo rol base
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t base

dev:            ## Devtools (vim, tmux+TPM, pipx, ansible-lint)
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t dev

containers:     ## Contenedores (Podman por defecto)
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t containers

gaming:         ## Steam/Proton/Lutris/Gamemode
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t gaming

ai:             ## Tooling IA mínimo (CUDA toolkit en Debian/Ubuntu)
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t ai

security:       ## UFW, fail2ban, endurecimiento SSH
	ansible-playbook -i inventories/local/hosts.yml site.yml -K -t security

lint:           ## Lint de Ansible (local)
	ansible-lint
