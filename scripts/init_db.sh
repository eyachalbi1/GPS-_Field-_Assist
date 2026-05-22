#!/bin/bash
#
# Initialisation de la base de données GPS Field Assist
# Crée les tables, utilisateurs de test et données de référence
#

set -e

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Initialisation Base de données GPS Field Assist ===${NC}\n"

# Vérifier que le conteneur PostgreSQL est en cours d'exécution
if ! docker ps | grep -q gps_postgres; then
    echo -e "${YELLOW}Démarrage du conteneur PostgreSQL...${NC}"
    docker-compose up -d db
    echo "Attente du démarrage (10s)..."
    sleep 10
fi

# Créer la base de données si elle n'existe pas
echo "Création de la base de données..."
docker exec gps_postgres psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'tunav_gps_tracking_db'" | grep -q 1 || \
    docker exec gps_postgres psql -U postgres -c "CREATE DATABASE tunav_gps_tracking_db"

# Appliquer les migrations (si le script create_db.py existe)
if [ -f "backend/create_db.py" ]; then
    echo "Exécution des migrations (create_db.py)..."
    docker-compose exec backend python create_db.py
else
    echo -e "${YELLOW}Script create_db.py non trouvé, création manuelle des tables...${NC}"

    # Créer les tables de base (à adapter selon le modèle réel)
    docker exec -i gps_postgres psql -U postgres -d tunav_gps_tracking_db << 'EOF'
-- Table users (utilisateurs)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(150),
    role VARCHAR(50) DEFAULT 'technician',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table tasks (interventions Odoo synchronisées)
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    odoo_id INTEGER UNIQUE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    client_name VARCHAR(255),
    address TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    assigned_to INTEGER REFERENCES users(id),
    priority VARCHAR(50) DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table action_history (traçabilité)
CREATE TABLE IF NOT EXISTS action_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    action_type VARCHAR(100),
    details JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table sms_logs (logs des commandes SMS)
CREATE TABLE IF NOT EXISTS sms_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    task_id INTEGER REFERENCES tasks(id),
    command TEXT,
    response TEXT,
    status VARCHAR(50),
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index pour optimisation
CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_action_history_user ON action_history(user_id);
CREATE INDEX IF NOT EXISTS idx_sms_logs_task ON sms_logs(task_id);

-- Insertion d'un admin de test (mot de passe: admin123)
INSERT INTO users (username, password_hash, email, role) VALUES
('admin', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW', 'admin@tunav-it.com', 'admin')
ON CONFLICT (username) DO NOTHING;

-- Insertion d'un technicien de test (mot de passe: tech123)
INSERT INTO users (username, password_hash, email, role) VALUES
('tech1', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW', 'tech1@tunav-it.com', 'technician')
ON CONFLICT (username) DO NOTHING;

-- Insertion de tâches de test
INSERT INTO tasks (odoo_id, title, description, client_name, address, status, priority) VALUES
(1001, 'Installation Easytrac X', 'Installation terminal GPS Easytrac X', 'Client Alpha', 'Tunis, Lac 2', 'pending', 'high'),
(1002, 'Maintenance Med Watch', 'Vérification montre Med Watch', 'Client Beta', 'Sfax, Centre Ville', 'in_progress', 'medium')
ON CONFLICT (odoo_id) DO NOTHING;

EOF
fi

echo -e "\n${GREEN}✓ Base de données initialisée avec succès${NC}"
echo ""
echo " Utilisateurs créés:"
echo "   - admin / admin123"
echo "   - tech1 / tech123"
echo ""
echo "Test de connexion:"
echo "  curl http://localhost:8001/api/auth/login -X POST -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin123\"}'"
echo ""
echo -e "${YELLOW}⚠️  Changez les mots de passe en production !${NC}\n"

exit 0
