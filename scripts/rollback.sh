#!/bin/bash
#
# Script de rollback pour GPS Field Assist
# Permet de revenir à une version précédente en une commande
#

set -e

# Configuration
BACKEND_IMAGE="gps-field-assist-backend"
COMPOSE_FILE="docker-compose.yml"
ROLLBACK_LOG="/var/log/gps-field-assist/rollback.log"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${ROLLBACK_LOG}"
}

# Lister les images disponibles
list_images() {
    echo "Images disponibles pour ${BACKEND_IMAGE}:"
    echo "----------------------------------------"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}" "${BACKEND_IMAGE}"* 2>/dev/null || echo "Aucune image trouvée"
    echo ""
}

# Fonction d'aide
show_help() {
    cat << EOF
Usage: $0 [OPTION]

Options:
    list          Lister toutes les versions disponibles
    rollback TAG  Revenir à la version spécifiée (ex: rollback 20240101_120000)
    latest        Revenir à la dernière version stable (rollback automatique)
    auto          Effectuer un rollback automatique en cas d'échec du healthcheck
    help          Afficher cette aide

Examples:
    $0 list
    $0 rollback 20240101_120000
    $0 latest

Notes:
    - Les tags sont des timestamps (YYYYMMDD_HHMMSS) générés par Jenkins
    - Le tag 'latest' pointe toujours vers la dernière version stable
    - En cas d'échec du déploiement, exécutez '$0 auto' pour rollback automatique

EOF
}

# Rollback simple
do_rollback() {
    local tag=$1

    log "=== Début du rollback vers ${tag} ==="

    # Vérifier que l'image existe
    if ! docker image inspect "${BACKEND_IMAGE}:${tag}" >/dev/null 2>&1; then
        log "ERREUR: Image ${BACKEND_IMAGE}:${tag} introuvable"
        echo -e "${RED}Erreur: Image introuvable${NC}"
        exit 1
    fi

    # Arrêter le service backend
    log "Arrêt du service backend..."
    docker-compose stop backend || true

    # Sauvegarder l'image actuelle (pour rollback ultérieur)
    local current_tag
    current_tag=$(docker images --format "{{.Tag}}" "${BACKEND_IMAGE}:latest" 2>/dev/null | head -1)
    if [ -n "${current_tag}" ]; then
        log "Image actuelle sauvegardée: ${current_tag}"
    fi

    # Mettre à jour le tag latest
    log "Mise à jour du tag latest vers ${tag}..."
    docker tag "${BACKEND_IMAGE}:${tag}" "${BACKEND_IMAGE}:latest"

    # Redémarrer le service avec la nouvelle image
    log "Redémarrage du service backend..."
    docker-compose up -d backend

    # Attendre que le service soit prêt
    log "Attente du démarrage (30s)..."
    sleep 30

    # Vérifier le healthcheck
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' gps_backend 2>/dev/null || echo "unavailable")

    if [ "${health_status}" = "healthy" ]; then
        log "Rollback réussi! Service healthy."
        echo -e "${GREEN}✓ Rollback réussi vers ${tag}${NC}"
    else
        log "ALERTE: Service non healthy après rollback (status: ${health_status})"
        echo -e "${RED}✗ Service non healthy après rollback${NC}"
        echo "Vérifiez les logs: docker logs gps_backend"
        exit 1
    fi

    log "=== Rollback terminé ==="
}

# Rollback automatique (en cas d'échec du déploiement)
auto_rollback() {
    log "=== Rollback automatique déclenché ==="

    # Récupérer le dernier tag connu comme stable
    local stable_tag
    stable_tag=$(docker images --format "{{.Tag}}" "${BACKEND_IMAGE}" 2>/dev/null | grep -E '^[0-9]{8}_[0-9]{6}$' | sort | tail -2 | head -1)

    if [ -z "${stable_tag}" ]; then
        log "ERREUR: Aucune version stable trouvée"
        echo -e "${RED}Impossible de trouver une version stable${NC}"
        exit 1
    fi

    log "Version stable identifiée: ${stable_tag}"
    do_rollback "${stable_tag}"
}

# Programme principal
case "${1:-help}" in
    list)
        list_images
        ;;
    rollback)
        if [ -z "${2}" ]; then
            echo -e "${RED}Erreur: Tag requis${NC}"
            show_help
            exit 1
        fi
        do_rollback "${2}"
        ;;
    latest)
        # Trouver le deuxième tag le plus récent (le plus récent est celui qui vient d'être déployé et peut être cassé)
        local tags
        tags=$(docker images --format "{{.Tag}}" "${BACKEND_IMAGE}" 2>/dev/null | grep -E '^[0-9]{8}_[0-9]{6}$' | sort)
        local rollback_tag
        rollback_tag=$(echo "${tags}" | tail -2 | head -1)

        if [ -z "${rollback_tag}" ]; then
            echo -e "${RED}Aucune version précédente trouvée${NC}"
            exit 1
        fi

        echo -e "${YELLOW}Rollback vers: ${rollback_tag}${NC}"
        do_rollback "${rollback_tag}"
        ;;
    auto)
        auto_rollback
        ;;
    help|*)
        show_help
        ;;
esac
