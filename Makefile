.PHONY: install setup check dry-run

# Цвета
GREEN := \033[0;32m
NC := \033[0m

install: ## Установка зависимостей Ansible
	@echo "$(GREEN)Установка коллекций...$(NC)"
	ansible-galaxy collection install -r requirements.yml --force

check: ## Проверка доступности хостов
	ansible -m ping all

setup: ## Полная настройка серверов согласно group_vars
	@echo "$(GREEN)Запуск настройки...$(NC)"
	ansible-playbook playbooks/main.yml

dry-run: ## Пробный запуск (покажет изменения, но не применит их)
	ansible-playbook playbooks/main.yml --check --diff

# Пример запуска конкретной роли: make run tags=ssh
run:
	ansible-playbook playbooks/main.yml --tags "$(tags)"
