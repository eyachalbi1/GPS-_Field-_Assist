#!/bin/bash
# vm-setup.sh — Script d'installation complet pour VM Ubuntu (VMware Workstation)
# Usage: sudo bash vm-setup.sh

set -e

echo "=== GPS Field Assist — Setup VM ==="

# 1. Prérequis système
apt-get update -qq
apt-get install -y --no-install-recommends \
    git curl ca-certificates gnupg lsb-release make \
    sysfsutils

# SonarQube nécessite vm.max_map_count >= 524288
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
sysctl -w vm.max_map_count=524288

# 2. Docker
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker "$SUDO_USER"
fi

# 3. Docker Compose v2
if ! docker compose version &>/dev/null; then
    apt-get install -y docker-compose-plugin
fi

# 4. Cloner le projet (adapter l'URL)
REPO_URL="${REPO_URL:-https://github.com/votre-org/gps-field-assist.git}"
DEST="/opt/gps-field-assist"

if [ ! -d "$DEST" ]; then
    git clone "$REPO_URL" "$DEST"
else
    git -C "$DEST" pull
fi

cd "$DEST"

# 5. Fichiers .env
[ -f backend/.env ] || cp backend/.env.example backend/.env
[ -f .env ] || cp .env.docker .env

# 6. Démarrer l'infrastructure
docker compose up -d --build

# 7. Attendre que les services soient prêts
echo "Attente des services (60s)..."
sleep 60

# 8. Initialiser la base de données
bash "$DEST/scripts/init_db.sh"

# 9. Vérification du déploiement
bash "$DEST/scripts/verify-deployment.sh" || true

IP=$(hostname -I | awk '{print $1}')
echo ""
echo "=== Accès ==="
echo "  Backend API  : http://${IP}:8001"
echo "  API Docs     : http://${IP}:8001/docs"
echo "  Jenkins      : http://${IP}:9090"
echo "  Prometheus   : http://${IP}:9091"
echo "  Grafana      : http://${IP}:3000  (admin / admin123)"
echo "  SonarQube    : http://${IP}:9000  (admin / admin)"
echo ""
echo "IMPORTANT: Attendez ~2 min que SonarQube démarre complètement."
echo "Puis dans Jenkins : Manage Jenkins > Configure System > SonarQube servers"
echo "  Name: SonarQube"
echo "  URL : http://sonarqube:9000"
echo "  Token: générer dans SonarQube > My Account > Security"
