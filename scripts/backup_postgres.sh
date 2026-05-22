#!/bin/bash
#
# Script de sauvegarde automatique PostgreSQL pour GPS Field Assist
# Ce script est exécuté quotidiennement via cron ou systemd timer
#

set -e

# Configuration
BACKUP_DIR="/var/backups/gps-field-assist"
DB_CONTAINER="gps_postgres"
DB_NAME="tunav_gps_tracking_db"
DB_USER="postgres"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql.gz"

# Créer le dossier de backup s'il n'existe pas
mkdir -p "${BACKUP_DIR}"

echo "[$(date)] Début de la sauvegarde PostgreSQL..."

# Vérifier que le conteneur Docker est en cours d'exécution
if ! docker ps | grep -q "${DB_CONTAINER}"; then
    echo "ERREUR: Le conteneur ${DB_CONTAINER} n'est pas en cours d'exécution!"
    exit 1
fi

# Effectuer le dump de la base de données
echo "Sauvegarde de la base ${DB_NAME}..."
docker exec "${DB_CONTAINER}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" | gzip > "${BACKUP_FILE}"

# Vérifier que le fichier de backup a été créé
if [ ! -f "${BACKUP_FILE}" ]; then
    echo "ERREUR: Le fichier de sauvegarde n'a pas été créé!"
    exit 1
fi

# Afficher la taille du fichier
BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
echo "Sauvegarde créée: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Nettoyer les anciennes sauvegardes (conservation 7 jours)
echo "Nettoyage des sauvegardes de plus de ${RETENTION_DAYS} jours..."
find "${BACKUP_DIR}" -name "backup_*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete

# Compter les sauvegardes restantes
REMAINING_BACKUPS=$(ls -1 "${BACKUP_DIR}"/backup_*.sql.gz 2>/dev/null | wc -l)
echo "Sauvegardes conservées: ${REMAINING_BACKUPS}"

# Tester la restauration (optionnel - désactivé par défaut pour éviter la perte de données)
# Décommenter pour tester la restauration automatique (ATTENTION: écrasement des données!)
# RESTORE_TEST_FILE="${BACKUP_DIR}/restore_test_${TIMESTAMP}.sql.gz"
# cp "${BACKUP_FILE}" "${RESTORE_TEST_FILE}"
# echo "Test de restauration désactivé (sécurité)"

echo "[$(date)] Sauvegarde terminée avec succès."

# Journalisation vers syslog
logger -t gps-field-assist "Backup PostgreSQL réussi: ${BACKUP_FILE}"

exit 0
