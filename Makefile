.PHONY: help build up down logs clean backup restore test deploy rollback status

# Variables
COMPOSE_FILE = docker-compose.yml
BACKEND_DIR = backend
MOBILE_DIR = mobile
SCRIPTS_DIR = scripts

help: ## Afficher cette aide
	@echo "GPS Field Assist - Commandes DevOps"
	@echo ""
	@echo "Usage: make [cible]"
	@echo ""
	@echo "Cibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Construire les images Docker
	@echo "Construction des images Docker..."
	docker-compose build
	@echo "✓ Images construites"

up: ## Démarrer tous les services (detached)
	@echo "Démarrage des services..."
	docker-compose up -d
	@echo "✓ Services démarrés"
	@echo "  - Backend: http://localhost:8001"
	@echo "  - Jenkins: http://localhost:9090"
	@echo "  - PostgreSQL: localhost:5433"

down: ## Arrêter tous les services
	@echo "Arrêt des services..."
	docker-compose down
	@echo "✓ Services arrêtés"

logs: ## Afficher les logs de tous les services
	docker-compose logs -f

logs-backend: ## Logs du backend seulement
	docker-compose logs -f backend

logs-db: ## Logs de la base de données
	docker-compose logs -f db

logs-jenkins: ## Logs de Jenkins
	docker-compose logs -f jenkins

logs-prometheus: ## Logs de Prometheus
	docker-compose logs -f prometheus

logs-grafana: ## Logs de Grafana
	docker-compose logs -f grafana

logs-sonar: ## Logs de SonarQube
	docker-compose logs -f sonarqube

clean: ## Nettoyer les conteneurs, images et volumes inutilisés
	@echo "Nettoyage Docker..."
	docker-compose down -v
	docker system prune -f --filter "until=24h"
	@echo "✓ Nettoyage terminé"

backup: ## Effectuer une sauvegarde manuelle de PostgreSQL
	@echo "Sauvegarde PostgreSQL..."
	@mkdir -p /var/backups/gps-field-assist
	docker exec gps_postgres pg_dump -U postgres tunav_gps_tracking_db | gzip > /var/backups/gps-field-assist/backup_$(shell date +%Y%m%d_%H%M%S).sql.gz
	@echo "✓ Sauvegarde créée dans /var/backups/gps-field-assist/"

restore: ## Restaurer une sauvegarde (spécifier FILE=path/to/backup.sql.gz)
	@if [ -z "$(FILE)" ]; then echo "Erreur: spécifiez FILE=path/to/backup.sql.gz"; exit 1; fi
	@echo "Restauration depuis $(FILE)..."
	pip install pg_restore || true
	gunzip -c $(FILE) | docker exec -i gps_postgres psql -U postgres -d tunav_gps_tracking_db
	@echo "✓ Restauration terminée"

test: ## Lancer les tests backend
	@echo "Tests backend..."
	cd $(BACKEND_DIR) && pytest tests/ -v --cov=src
	@echo "✓ Tests terminés"

test-flutter: ## Linter et tests Flutter
	@echo "Analyse Flutter..."
	cd $(MOBILE_DIR) && flutter analyze
	@echo "✓ Analyse terminée"

deploy: ## Déploiement complet (build + up)
	@echo "Déploiement GPS Field Assist..."
	$(MAKE) build
	$(MAKE) up
	@echo "✓ Déploiement terminé"
	@echo "Vérifiez: http://localhost:8001/health"

rollback: ## Rollback vers la version précédente (spécifiez TAG ou utilisez latest)
	@if [ -z "$(TAG)" ]; then echo "Usage: make rollback TAG=<timestamp>"; echo "Ou: make rollback-latest"; exit 1; fi
	@echo "Rollback vers $(TAG)..."
	$(SCRIPTS_DIR)/rollback.sh rollback $(TAG)

rollback-list: ## Lister les versions disponibles pour rollback
	$(SCRIPTS_DIR)/rollback.sh list

rollback-latest: ## Rollback vers la dernière version stable
	@echo "Rollback automatique..."
	$(SCRIPTS_DIR)/rollback.sh latest

rollback-auto: ## Rollback d'urgence automatique
	$(SCRIPTS_DIR)/rollback.sh auto

status: ## Afficher le statut de tous les services
	@echo "Statut des services GPS Field Assist:"
	@echo "====================================="
	@docker-compose ps
	@echo ""
	@echo "Backend API:"
	@curl -s http://localhost:8001/health || echo "  ❌ API non accessible"
	@echo ""
	@echo "Base de données:"
	@docker exec gps_postgres pg_isready -U postgres || echo "  ❌ DB non accessible"
	@echo ""
	@echo "Espace disque:"
	@df -h / | awk 'NR==2 {print "  Utilisation: "$5}'
	@echo ""
	@echo "Logs récents (backend):"
	@docker-compose logs --tail=5 backend || true

verify: ## Vérification complète du déploiement
	@chmod +x $(SCRIPTS_DIR)/verify-deployment.sh
	$(SCRIPTS_DIR)/verify-deployment.sh

init-db: ## Initialiser la base de données (1ère fois)
	@chmod +x $(SCRIPTS_DIR)/init_db.sh
	$(SCRIPTS_DIR)/init_db.sh

ssl-generate: ## Générer des certificats SSL auto-signés pour le développement
	@echo "Génération certificats SSL..."
	@chmod +x $(SCRIPTS_DIR)/generate_ssl.sh
	$(SCRIPTS_DIR)/generate_ssl.sh localhost
	@echo "✓ Certificats générés dans nginx/ssl/"

monitor: ## Lancer le monitoring manuellement
	@echo "Monitoring des services..."
	@chmod +x $(SCRIPTS_DIR)/monitor_services.sh
	$(SCRIPTS_DIR)/monitor_services.sh

backup-cron: ## Installer les tâches cron (nécessite sudo)
	@echo "Installation des tâches cron..."
	@if [ -d /etc/cron.d ]; then \
		cp $(SCRIPTS_DIR)/gps-field-assist.crontab /etc/cron.d/gps-field-assist; \
		echo "✓ Tâches cron installées"; \
	else \
		echo "Erreur: /etc/cron.d non trouvé (non Linux?)"; \
	fi

shell-backend: ## Ouvrir un shell dans le conteneur backend
	docker-compose exec backend /bin/bash

shell-db: ## Ouvrir un shell psql dans le conteneur PostgreSQL
	docker-compose exec db psql -U postgres -d tunav_gps_tracking_db

restart: ## Redémarrer tous les services
	@echo "Redémarrage..."
	docker-compose restart

sonar: ## Lancer l'analyse SonarQube manuellement
	@echo "Analyse SonarQube..."
	cd $(BACKEND_DIR) && sonar-scanner \
		-Dsonar.projectKey=gps-field-assist \
		-Dsonar.host.url=http://localhost:9000

migrate: ## Appliquer les migrations de base de données (si utilisées)
	@echo "Migration..."
	# Ajouter les commandes de migration ici si nécessaire
	@echo "✓ Aucune migration requise"
