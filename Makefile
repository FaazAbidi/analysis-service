.PHONY: build up down restart logs ps shell-web shell-worker shell-flower clean clean-all help

# Default target
.DEFAULT_GOAL := help

# Variables
DC = docker-compose

help:
	@echo "Available commands:"
	@echo "  make build       - Build all Docker images"
	@echo "  make up          - Start all services in detached mode"
	@echo "  make down        - Stop all services"
	@echo "  make restart     - Restart all services"
	@echo "  make logs        - Show logs from all services"
	@echo "  make logs-web    - Show logs from web service"
	@echo "  make logs-worker - Show logs from worker service"
	@echo "  make logs-flower - Show logs from flower service"
	@echo "  make ps          - Show running containers"
	@echo "  make shell-web   - Open shell in web container"
	@echo "  make shell-worker - Open shell in worker container"
	@echo "  make shell-flower - Open shell in flower container"
	@echo "  make clean       - Remove containers and networks"
	@echo "  make clean-all   - Remove containers, networks, volumes, and images"

build:
	$(DC) build

up:
	$(DC) up -d

down:
	$(DC) down

restart:
	$(DC) restart

logs:
	$(DC) logs -f

logs-web:
	$(DC) logs -f web

logs-worker:
	$(DC) logs -f worker

logs-flower:
	$(DC) logs -f flower

ps:
	$(DC) ps

shell-web:
	$(DC) exec web bash || $(DC) exec web sh

shell-worker:
	$(DC) exec worker bash || $(DC) exec worker sh

shell-flower:
	$(DC) exec flower bash || $(DC) exec flower sh

clean:
	$(DC) down

clean-all:
	$(DC) down -v --rmi all

run-local:
	python app.py

run-worker-local:
	celery --app tasks worker --loglevel info

run-flower-local:
	celery flower --app tasks --loglevel info 