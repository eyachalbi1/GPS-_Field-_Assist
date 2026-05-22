#!/bin/bash
#
# Vérification complète du déploiement GPS Field Assist
# Exécute tous les tests de santé et d'intégration
#

set -e

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

# Fonction de test
run_test() {
    local name="$1"
    local command="$2"
    local expected="$3"

    echo -n "Testing: ${name}... "

    if eval "${command}" &>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
    fi
}

# Fonction de test HTTP
run_http_test() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"

    echo -n "Testing: ${name}... "

    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || echo "000")

    if [ "${code}" = "${expected_code}" ]; then
        echo -e "${GREEN}✓ PASS (HTTP ${code})${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL (HTTP ${code}, expected ${expected_code})${NC}"
        ((FAILED++))
    fi
}

echo "============================================"
echo "  GPS Field Assist - Deployment Verification"
echo "============================================"
echo ""

# 1. Vérification Docker
echo -e "${BLUE}[1/8] Vérification Docker...${NC}"
if command -v docker &>/dev/null; then
    echo "  Docker version: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'unknown')"
    run_test "Docker daemon running" "docker info" ""
else
    echo -e "  ${RED}Docker non installé${NC}"
    exit 1
fi

# 2. Vérification Docker Compose
echo -e "\n${BLUE}[2/8] Vérification Docker Compose...${NC}"
if command -v docker-compose &>/dev/null; then
    run_test "docker-compose version" "docker-compose version" ""
else
    echo -e "${RED}docker-compose non installé${NC}"
    exit 1
fi

# 3. Vérification des conteneurs
echo -e "\n${BLUE}[3/8] Vérification des conteneurs...${NC}"
run_test "PostgreSQL container running" "docker ps | grep -q gps_postgres" ""
run_test "Backend container running" "docker ps | grep -q gps_backend" ""
run_test "Jenkins container running" "docker ps | grep -q gps_jenkins" ""
run_test "Nginx container running" "docker ps | grep -q gps_nginx" ""
run_test "Prometheus container running" "docker ps | grep -q gps_prometheus" ""
run_test "Grafana container running" "docker ps | grep -q gps_grafana" ""
run_test "SonarQube container running" "docker ps | grep -q gps_sonarqube" ""

# 4. Vérification des ports
echo -e "\n${BLUE}[4/8] Vérification des ports...${NC}"
run_test "PostgreSQL port 5433" "nc -z localhost 5433" ""
run_test "Backend API port 8001" "nc -z localhost 8001" ""
run_test "Jenkins UI port 9090" "nc -z localhost 9090" ""
run_test "Nginx HTTPS port 443" "nc -z localhost 443" ""
run_test "Prometheus port 9091" "nc -z localhost 9091" ""
run_test "Grafana port 3000" "nc -z localhost 3000" ""
run_test "SonarQube port 9000" "nc -z localhost 9000" ""

# 5. Vérification API
echo -e "\n${BLUE}[5/8] Vérification API Backend...${NC}"
run_http_test "Backend health endpoint" "http://localhost:8001/health" "200"
run_http_test "Backend auth endpoint" "http://localhost:8001/api/auth/login" "405"  # Méthode non autorisée sans POST, mais endpoint existe
run_http_test "API docs (Swagger)" "http://localhost:8001/docs" "200"

# 6. Vérification Base de données
echo -e "\n${BLUE}[6/8] Vérification PostgreSQL...${NC}"
run_test "Database connectivity" "docker exec gps_postgres pg_isready -U postgres" ""
run_test "Database exists" "docker exec gps_postgres psql -U postgres -lqt | cut -d \| -f 1 | grep -qw tunav_gps_tracking_db" ""
run_test "Default admin user" "docker exec gps_postgres psql -U postgres -d tunav_gps_tracking_db -c '\du' | grep -q admin" ""

# 7. Vérification Jenkins
echo -e "\n${BLUE}[7/8] Vérification Jenkins...${NC}"
run_http_test "Jenkins UI" "http://localhost:9090" "200"
run_test "Jenkins job exists" "curl -s http://localhost:9090/job/gps-field-assist/api/json 2>/dev/null | grep -q 'gps-field-assist'" ""

# 8. Vérification Nginx/SSL
echo -e "\n${BLUE}[8/8] Vérification Nginx/SSL...${NC}"
run_http_test "Nginx HTTP → HTTPS redirect" "http://localhost" "301"
run_http_test "Nginx HTTPS endpoint" "https://localhost -k" "200"  # -k ignore SSL errors

# 9. Vérification Monitoring
echo -e "\n${YELLOW}[9/11] Vérification Monitoring...${NC}"
run_http_test "Prometheus UI" "http://localhost:9091" "200"
run_http_test "Grafana UI" "http://localhost:3000" "200"
run_http_test "SonarQube UI" "http://localhost:9000" "200"

# 10. Vérification des volumes
echo -e "\n${YELLOW}[10/11] Vérification des volumes...${NC}"
run_test "PostgreSQL volume exists" "docker volume ls | grep -q postgres_data" ""
run_test "Jenkins volume exists" "docker volume ls | grep -q jenkins_home" ""
run_test "Prometheus volume exists" "docker volume ls | grep -q prometheus_data" ""
run_test "Grafana volume exists" "docker volume ls | grep -q grafana_data" ""

# 11. Vérification des scripts
echo -e "\n${YELLOW}[11/11] Vérification scripts...${NC}"
run_test "Backup script executable" "[ -x scripts/backup_postgres.sh ]" ""
run_test "Monitor script executable" "[ -x scripts/monitor_services.sh ]" ""
run_test "Rollback script executable" "[ -x scripts/rollback.sh ]" ""

# Résumé
echo ""
echo "============================================"
echo -e "  Résultats: ${GREEN}${PASSED} passé(s)${NC} / ${RED}${FAILED} échoué(s)${NC}"
echo "============================================"

if [ ${FAILED} -eq 0 ]; then
    echo -e "\n${GREEN}✓ Déploiement entièrement fonctionnel !${NC}"
    echo ""
    echo "Services disponibles:"
    echo "  • Backend API: http://localhost:8001"
    echo "  • API Docs:    http://localhost:8001/docs"
    echo "  • Jenkins:     http://localhost:9090"
    echo "  • Prometheus:  http://localhost:9091"
    echo "  • Grafana:     http://localhost:3000  (admin/admin123)"
    echo "  • SonarQube:   http://localhost:9000  (admin/admin)"
    echo "  • PostgreSQL:  localhost:5433"
    echo ""
    exit 0
else
    echo -e "\n${RED}✗ Déploiement incomplet - ${FAILED} test(s) échoué(s)${NC}"
    echo ""
    echo "Actions recommandées:"
    echo "  1. Consulter les logs: docker-compose logs -f"
    echo "  2. Redémarrer les services: make restart"
    echo "  3. Vérifier les ressources système (RAM/CPU)"
    echo ""
    exit 1
fi
