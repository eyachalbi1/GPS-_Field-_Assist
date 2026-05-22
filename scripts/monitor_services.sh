#!/bin/bash
#
# Script de monitoring des services GPS Field Assist
# Vérifie l'état de santé des conteneurs et envoie des alertes
#

set -e

# Configuration
SERVICES=("gps_postgres" "gps_backend" "gps_jenkins")
WEB_BACKEND_URL="http://localhost:8001/health"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
EMAIL_RECIPIENT="${MONITOR_EMAIL:-devops@tunav-it.com}"
LOG_FILE="/var/log/gps-field-assist/monitoring.log"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Créer le dossier de logs
mkdir -p "$(dirname "${LOG_FILE}")"

# Fonction pour logger
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Fonction pour envoyer une alerte Slack
send_slack_alert() {
    local service=$1
    local status=$2
    local message="🚨 *Service ${service}* est *${status}*\nVérifiez le service GPS Field Assist sur $(hostname)"
    if [ -n "${SLACK_WEBHOOK}" ]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"${message}\"}" \
            "${SLACK_WEBHOOK}" || true
    fi
}

# Fonction pour envoyer un email
send_email_alert() {
    local service=$1
    local status=$2
    local subject="[ALERTE] Service ${service} - ${status}"
    local body="Le service ${service} est en état ${status} sur le serveur $(hostname).\n\nVérifiez les logs: ${LOG_FILE}\n\nTimestamp: $(date)"
    echo "${body}" | mail -s "${subject}" "${EMAIL_RECIPIENT}" || true
}

# Vérification des conteneurs Docker
check_containers() {
    local all_ok=true

    for service in "${SERVICES[@]}"; do
        if docker ps | grep -q "${service}"; then
            local container_status=$(docker inspect -f '{{.State.Status}}' "${service}" 2>/dev/null || echo "missing")
            if [ "${container_status}" = "running" ]; then
                log_message "INFO" "Conteneur ${service}: OK (running)"
            else
                log_message "ERROR" "Conteneur ${service}: ${container_status}"
                send_slack_alert "${service}" "${container_status}"
                send_email_alert "${service}" "${container_status}"
                all_ok=false
            fi
        else
            log_message "ERROR" "Conteneur ${service}: NON TROUVÉ"
            send_slack_alert "${service}" "MISSING"
            send_email_alert "${service}" "MISSING"
            all_ok=false
        fi
    done

    return $([ "${all_ok}" = true ] && echo 0 || echo 1)
}

# Vérification de l'API Backend
check_backend_api() {
    local response
    local http_code

    response=$(curl -s -o /dev/null -w "%{http_code}" "${WEB_BACKEND_URL}" --max-time 10 2>/dev/null || echo "000")

    if [ "${response}" = "200" ]; then
        log_message "INFO" "API Backend: OK (HTTP 200)"
        return 0
    else
        log_message "ERROR" "API Backend: HTTP ${response}"
        send_slack_alert "Backend API" "HTTP ${response}"
        send_email_alert "Backend API" "HTTP ${response}"
        return 1
    fi
}

# Vérification de l'espace disque
check_disk_space() {
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

    if [ "${disk_usage}" -gt 85 ]; then
        log_message "WARNING" "Espace disque critique: ${disk_usage}% utilisé"
        send_slack_alert "Disk Space" "${disk_usage}%"
    elif [ "${disk_usage}" -gt 70 ]; then
        log_message "WARNING" "Espace disque élevé: ${disk_usage}% utilisé"
    else
        log_message "INFO" "Espace disque: ${disk_usage}% utilisé"
    fi
}

# Vérification de la mémoire
check_memory() {
    local mem_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')

    if [ "${mem_usage}" -gt 90 ]; then
        log_message "WARNING" "Mémoire critique: ${mem_usage}% utilisé"
        send_slack_alert "Memory" "${mem_usage}%"
    else
        log_message "INFO" "Mémoire: ${mem_usage}% utilisé"
    fi
}

# Statistiques Docker
show_docker_stats() {
    log_message "INFO" "Statistiques Docker:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -5 >> "${LOG_FILE}" 2>&1 || true
}

# Programme principal
main() {
    log_message "INFO" "=== Début du monitoring GPS Field Assist ==="

    check_containers
    check_backend_api
    check_disk_space
    check_memory
    show_docker_stats

    log_message "INFO" "=== Fin du monitoring ==="
    echo ""
}

# Exécution
main
