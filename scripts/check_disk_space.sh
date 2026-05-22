#!/bin/bash
#
# Vérification de l'espace disque pour GPS Field Assist
#

set -e

THRESHOLD=85
LOG_FILE="/var/log/gps-field-assist/disk_monitoring.log"

CURRENT_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

echo "[$(date)] Espace disque: ${CURRENT_USAGE}%" >> "${LOG_FILE}"

if [ "${CURRENT_USAGE}" -ge "${THRESHOLD}" ]; then
    echo "ALERTE: Espace disque critique (${CURRENT_USAGE}%)" | tee -a "${LOG_FILE}"

    # Nettoyage automatique des anciens backups
    if [ -d "/var/backups/gps-field-assist" ]; then
        echo "Nettoyage des anciennes sauvegardes..." >> "${LOG_FILE}"
        find /var/backups/gps-field-assist -name "*.sql.gz" -type f -mtime +3 -delete
    fi

    # Nettoyage Docker
    echo "Nettoyage Docker..." >> "${LOG_FILE}"
    docker system prune -f --filter "until=24h" >> "${LOG_FILE}" 2>&1 || true

    # Envoyer alerte
    logger -t gps-field-assist "ALERTE: Espace disque ${CURRENT_USAGE}% - nettoyage automatique déclenché"
fi

exit 0
