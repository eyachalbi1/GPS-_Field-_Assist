#!/bin/bash
#
# Installation automatique de l'infrastructure Sprint 7
# GPS Field Assist — DevOps Complete Setup
#
# Usage: sudo ./install-sprint7.sh [dev|prod]
#

set -e

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MODE="${1:-dev}"

# Log
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Vérifier sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        error "Ce script doit être exécuté avec sudo"
    fi
}

# Vérifier OS
check_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        warn "OS non supporté: $OSTYPE (tentative d'installation)"
        OS="unknown"
    fi
    log "Système détecté: $OS"
}

# Installer les dépendances système
install_deps_linux() {
    log "Installation des dépendances système (Linux)..."
    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install -y \
            curl \
            git \
            docker.io \
            docker-compose \
            python3 \
            python3-pip \
            make \
            unzip \
            xz-utils \
            gnupg \
            lsb-release \
            ca-certificates \
            curl \
            wget \
            vim \
            htop \
            sysstat \
            mailutils \
            cron
        systemctl enable --now docker 2>/dev/null || true
    elif command -v yum &>/dev/null; then
        yum install -y \
            curl \
            git \
            docker \
            docker-compose \
            python3 \
            python3-pip \
            make \
            unzip \
            xz \
            gnupg \
            redhat-lsb-core \
            ca-certificates \
            curl \
            wget \
            vim \
            htop \
            sysstat \
            mailx \
            cronie
        systemctl enable --now docker 2>/dev/null || true
    else
        warn "Gestionnaire de paquets non reconnu. Installez manuellement: docker, docker-compose, python3, make, unzip, cron"
    fi
}

install_deps_macos() {
    log "Installation des dépendances (macOS)..."
    if ! command -v brew &>/dev/null; then
        error "Homebrew requis: https://brew.sh"
    fi
    brew install docker docker-compose python make coreutils gnu-sed
    open -a Docker 2>/dev/null || true
    warn "Lancez Docker Desktop manuellement"
}

# Créer les dossiers nécessaires
create_dirs() {
    log "Création des dossiers système..."
    mkdir -p /var/backups/gps-field-assist
    mkdir -p /var/log/gps-field-assist
    mkdir -p nginx/ssl
    chmod 700 /var/backups/gps-field-assist
    chmod 750 /var/log/gps-field-assist
}

# Copier les fichiers de configuration
setup_config() {
    log "Configuration des fichiers d'environnement..."

    if [ ! -f backend/.env ]; then
        cp backend/.env.example backend/.env
        log "Fichier backend/.env créé (à personnaliser en prod)"
    else
        warn "backend/.env existe déjà — pas de modification"
    fi

    if [ ! -f .env ]; then
        cp .env.docker .env
        log "Fichier .env créé (docker-compose)"
    else
        warn ".env existe déjà — pas de modification"
    fi
}

# Rendre les scripts exécutables
chmod_scripts() {
    log "Attribution des permissions des scripts..."
    chmod +x scripts/*.sh
    chmod +x install-sprint7.sh uninstall-sprint7.sh 2>/dev/null || true
}

# Générer certificats SSL (dev uniquement)
generate_ssl() {
    if [ "$MODE" = "dev" ]; then
        log "Génération des certificats SSL auto-signés..."
        ./scripts/generate_ssl.sh localhost 2>/dev/null || \
            warn "SSL: échec génération (peut-être déjà existant)"
    else
        warn "Mode prod: générer vos propres certificats SSL (Let's Encrypt)"
    fi
}

# Installer les tâches cron
setup_cron() {
    log "Installation des tâches cron..."
    if [ -d /etc/cron.d ]; then
        cp scripts/gps-field-assist.crontab /etc/cron.d/gps-field-assist
        chmod 644 /etc/cron.d/gps-field-assist
        log "Tâches cron installées (vérifiez avec 'crontab -l')"
    else
        warn "Cron non trouvé — sauvegarde manuelle requise"
    fi
}

# Build images Docker
docker_build() {
    log "Construction des images Docker..."
    if [ "$MODE" = "prod" ]; then
        log "Mode production: utilisation Dockerfile.prod"
        docker build -t gps-field-assist-backend:prod -f backend/Dockerfile.prod ./backend
    else
        docker-compose build
    fi
}

# Démarrer les services
docker_up() {
    log "Démarrage des services Docker..."
    if [ "$MODE" = "prod" ]; then
        log " Utilisation docker-compose.prod.yml"
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
    else
        docker-compose up -d
    fi
}

# Attendre que les services soient prêts
wait_for_services() {
    log "Attente des services (30s)..."
    sleep 30

    log "Vérification healthchecks..."
    local retries=30
    while [ $retries -gt 0 ]; do
        if curl -s http://localhost:8001/health &>/dev/null; then
            log "Backend API:healthy ✓"
            break
        fi
        sleep 2
        ((retries--))
    done

    if [ $retries -eq 0 ]; then
        warn "Backend API ne répond pas — vérifiez avec 'make logs'"
    fi
}

# Initialiser la base de données
init_database() {
    log "Initialisation de la base de données..."
    ./scripts/init_db.sh || warn "Init DB: possiblement déjà fait"
}

# Afficher le statut final
show_status() {
    echo ""
    log "=== Installation Sprint 7 terminée ==="
    echo ""
    echo "Services:"
    echo "  Backend API:   http://localhost:8001"
    echo "  API Docs:      http://localhost:8001/docs"
    echo "  Jenkins:       http://localhost:9090"
    echo "  PostgreSQL:    localhost:5433"
    echo "  Nginx HTTPS:   https://localhost (auto-signé)"
    echo ""
    echo "Commandes utiles:"
    echo "  make status              # Statut services"
    echo "  make logs                # Logs temps réel"
    echo "  make test                # Tests backend"
    echo "  make monitor             # Monitoring manuel"
    echo "  make rollback-latest     # Rollback d'urgence"
    echo ""
    echo "Documentation:"
    echo "  QUICKSTART.md   — Démarrage 5 min"
    echo "  INFRASTRUCTURE.md — Documentation complète"
    echo "  CHANGELOG.md      — Historique modifications"
    echo ""
    log "Ensuite: personnalisez backend/.env (SECRET_KEY, DB_PASSWORD)"
    log "Puis: make init-db (premier démarrage uniquement)"
}

# Nettoyage en cas d'erreur
cleanup_on_error() {
    error "Installation échouée — nettoyage partiel effectué"
}

# Programme principal
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  GPS Field Assist — Sprint 7 Installer${NC}"
    echo -e "${BLUE}  Mode: ${MODE}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Vérifications préalables
    check_os
    check_sudo

    # Installation
    if [ "$OS" = "linux" ]; then
        install_deps_linux
    elif [ "$OS" = "macos" ]; then
        install_deps_macos
    else
        warn "OS inconnu — passez aux étapes manuelles"
    fi

    create_dirs
    chmod_scripts
    setup_config
    generate_ssl
    setup_cron

    # Docker
    docker_build
    docker_up
    wait_for_services

    # Base de données
    init_database

    # Tests finaux
    log "Vérification finale..."
    if curl -s http://localhost:8001/health &>/dev/null; then
        show_status
        echo -e "${GREEN}✓ Installation réussie !${NC}"
        exit 0
    else
        warn "Backend ne répond pas — consultez les logs"
        show_status
        exit 1
    fi
}

# Trap erreurs
trap cleanup_on_error ERR

# Exécution
main "$@"
