# GPS Field Assist — Infrastructure DevOps (Sprint 7)

![Sprint 7](https://img.shields.io/badge/Sprint-7-blue)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success)
![Docker](https://img.shields.io/badge/Docker-Compose-blue?logo=docker)
![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-orange?logo=jenkins)
![License](https://img.shields.io/badge/License-Proprietary-red)

> Infrastructure de déploiement complète pour l'application GPS Field Assist — Docker, Jenkins CI/CD, PostgreSQL, Nginx SSL, Monitoring & Backup.

## 🚀 Démarrage rapide

```bash
# Cloner et configurer
git clone <repo>
cd gps-field-assist
copy backend\.env.example backend\.env
copy .env.docker .env

# Démarrer l'infrastructure (5 min)
make up

# Vérifier
make status

# Initialiser la base de données
make init-db
```

**Accès:**
- Backend API: http://localhost:8001
- Documentation API: http://localhost:8001/docs
- Jenkins CI/CD: http://localhost:9090
- PostgreSQL: localhost:5433 (user: postgres, pass: postgres)

📖 **Voir [QUICKSTART.md](QUICKSTART.md) pour le guide complet.**

---

## 📦 Ce que contient ce dépôt

### Sprint 7 — Infrastructure DevOps

| Composant | Technologie | Description |
|-----------|-------------|-------------|
| **Orchestration** | Docker Compose | 4 services (db, backend, jenkins, nginx) |
| **CI/CD** | Jenkins | Pipeline automatisé (lint, test, build APK, déploiement) |
| **Base de données** | PostgreSQL 15 | Volumes persistants, sauvegarde automatique |
| **Serveur d'API** | FastAPI + Uvicorn/Gunicorn | Python 3.11, healthcheck, JWT auth |
| **Serveur web** | Nginx Alpine | Reverse proxy, SSL termination, rate limiting |
| **Monitoring** | Scripts Bash | Santé services, logs centralisés, alertes |
| **Backup** | pg_dump + cron | Sauvegarde quotidienne, rotation 7j |
| **Rollback** | Script custom | Retour version précédente en 1 commande |

### Structure du projet

```
gps-field-assist/
├── backend/               # API FastAPI + Dockerfile
│   ├── src/              # Code Python (routes, services)
│   ├── tests/            # Tests pytest
│   ├── Dockerfile        # Image dev
│   ├── Dockerfile.prod   # Image prod multi-stage
│   ├── .env              # Variables env (NON commit)
│   ├── .env.example      # Template
│   ├── requirements.txt  # Dépendances Python
│   └── static/           # Fichiers statiques (PDFs, images)
├── mobile/               # Application Flutter (code source)
├── jenkins/              # Configuration Jenkins
│   ├── Dockerfile        # Image Jenkins + Flutter SDK
│   └── plugins.txt      # Plugins requis
├── nginx/                # Configuration Nginx
│   ├── nginx.conf        # Config globale
│   ├── conf.d/          # Virtual hosts
│   └── ssl/             # Certificats SSL
├── scripts/              # Scripts d'opérations
│   ├── backup_postgres.sh
│   ├── monitor_services.sh
│   ├── rollback.sh
│   ├── init_db.sh
│   ├── generate_ssl.sh
│   └── verify-deployment.sh
├── docker-compose.yml    # Configuration principale
├── docker-compose.override.yml  # Dev (ports directs, hot-reload)
├── docker-compose.prod.yml      # Production (ressources limitées)
├── Jenkinsfile          # Pipeline CI/CD
├── Makefile             # Commandes DevOps (15+)
├── INFRASTRUCTURE.md    # Documentation complète
├── CI_CD_README.md      # CI/CD Jenkins détaillé
├── QUICKSTART.md        # Démarrage en 5 min
└── sprint7_chapter.tex  # Rapport LaTeX

```

---

## 🎯 User Stories Sprint 7 (8 US / 40 points)

| ID | Rôle | Fonctionnalité | Statut |
|----|------|----------------|--------|
| US-01 | Admin | Déployer backend avec Docker Compose | ✅ |
| US-02 | Admin | Configurer Jenkins CI/CD | ✅ |
| US-03 | Admin | Sécuriser communications HTTPS | ✅ |
| US-04 | Admin | Configurer PostgreSQL | ✅ |
| US-05 | Admin | Sauvegarde automatique | ✅ |
| US-06 | Admin | Monitoring des services | ✅ |
| US-07 | Admin | Variables d'environnement sécurisées | ✅ |
| US-08 | Admin | Déploiement rollback | ✅ |

**Taux d'achèvement: 100%**

---

## 🔧 Commandes Make principales

```bash
make up                  # Démarrer l'infrastructure
make down                # Tout arrêter
make logs                # Logs en temps réel
make status              # Statut des services
make test                # Tests backend (pytest)
make backup              # Sauvegarde manuelle DB
make monitor             # Monitoring manuel
make verify              # Vérification complète déploiement
make init-db             # Initialiser la base de données
make rollback-latest     # Rollback vers version précédente
make ssl-generate        # Générer certificats SSL
make clean               # Nettoyage Docker complet
```

Voir `Makefile` pour la liste complète (15+ commandes).

---

## 🏗️ Architecture Docker

```yaml
services:
  db:
    image: postgres:15-alpine
    ports: ["5433:5432"]
    volumes: [postgres_data:/var/lib/postgresql/data]
    healthcheck: pg_isready

  backend:
    build: ./backend
    ports: ["8001:8000"]
    depends_on: [db]
    healthcheck: curl /health
    volumes: [./backend/static:/app/static]

  jenkins:
    build: ./jenkins
    ports: ["9090:8080", "50000:50000"]
    volumes: [jenkins_home, /var/run/docker.sock]

  nginx:
    image: nginx:alpine
    ports: ["80:80", "443:443"]
    depends_on: [backend]
```

**Réseau:** `gps-network` (bridge isolé)

---

## 📊 Pipeline Jenkins

```
Git Push → Jenkins → [Checkout → Install → Lint → Test → Docker Build → Deploy → Flutter Build → Archive]
                                                              ↓
                                                Backend redémarré + APK généré
```

**Stages:**
1. **Checkout** — Récupère le code source
2. **Backend - Install** — `pip install -r requirements.txt`
3. **Backend - Lint** — `flake8` (qualité code)
4. **Backend - Test** — `pytest` + coverage
5. **Backend - Docker Build** — `docker build -t gps-backend`
6. **Backend - Docker Deploy** — `docker-compose up -d backend`
7. **Flutter - Setup** — `flutter pub get`
8. **Flutter - Analyze** — `flutter analyze`
9. **Flutter - Build APK** — `flutter build apk --release`
10. **Archive** — `app-release.apk` + rapports

**Notifications:** Slack + Email (succès/échec)

---

## 🔐 Sécurité

- **Secrets**: Stockés dans `.env` (non versionné), jamais en clair dans le code
- **Réseau**: Bridge isolé, seul Nginx expose ports externes
- **Users Docker**: `appuser` (non-root) dans conteneurs
- **SSL**: HTTPS obligatoire, redirection 301, HSTS headers
- **Rate limiting**: Nginx (10 req/s API, 5 req/min login)
- **Healthchecks**: Docker surveille db & backend
- **JWT**: Clé secrète dans `.env` (changer en prod!)

---

## 💾 Sauvegarde & Restauration

### Automatique (cron)
```bash
# Tous les jours à 2h du matin
0 2 * * * /usr/local/bin/backup_postgres.sh

# Rotation: 7 jours (dev), 30 jours (prod)
```

### Manuelle
```bash
make backup
# Fichiers: /var/backups/gps-field-assist/backup_*.sql.gz
```

### Restauration
```bash
gunzip -c backup_20240101_120000.sql.gz | \
  docker exec -i gps_postgres psql -U postgres -d tunav_gps_tracking_db
```

---

## 📈 Monitoring & Alertes

### Vérifications automatiques (toutes les 5 min)
- Docker conteneurs (running/healthy)
- API Backend (`/health` → 200)
- Espace disque (>85%)
- Mémoire (>90%)
- Stats Docker (CPU/RAM)

### Alertes
- **Slack**: webhook `SLACK_WEBHOOK_URL`
- **Email**: `mail` command (configurer MTA)
- **Syslog**: `logger -t gps-field-assist`

### Logs centralisés
```
/var/log/gps-field-assist/
├── monitoring.log
├── backup.log
└── rollback.log

/var/log/nginx/     # Access + error
/var/log/jenkins/   # Jenkins logs
backend/logs/       # App logs
```

---

## 🔄 Rollback (1 commande)

```bash
# Lister les images disponibles
make rollback-list

# Rollback vers un tag spécifique
make rollback TAG=20240101_120000

# Rollback automatique (dernière stable)
make rollback-latest

# Rollback d'urgence (auto en cas d'échec)
make rollback-auto
```

**Processus:**
1. Arrêt backend
2. Tag `latest` → image précédente
3. `docker-compose up -d backend`
4. Attente healthcheck
5. Validation: service healthy ✅

---

## 📚 Documentation

| Fichier | Description |
|---------|-------------|
| [QUICKSTART.md](QUICKSTART.md) | Démarrage en 5 minutes |
| [INFRASTRUCTURE.md](INFRASTRUCTURE.md) | Documentation technique complète |
| [CI_CD_README.md](CI_CD_README.md) | CI/CD Jenkins (pipeline, config) |
| [CHANGELOG.md](CHANGELOG.md) | Historique des modifications |
| [SPRINT7_SUMMARY.md](SPRINT7_SUMMARY.md) | Résumé du sprint 7 |
| [sprint7_chapter.tex](sprint7_chapter.tex) | Chapitre LaTeX pour rapport |

---

## ⚙️ Variables d'environnement critiques

### `.env` (backend)
```bash
SECRET_KEY=<64 chars aléatoires en production>
DB_PASSWORD=<mot de passe fort, min 32 chars>
```

### `.env.docker` (docker-compose)
```bash
POSTGRES_PASSWORD=postgres  # CHANGER en prod !
```

### Monitoring
```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
ALERT_EMAIL=devops@tunav-it.com
```

---

## ✅ Checklist production

Avant de déployer en production:

- [ ] Générer `SECRET_KEY`: `openssl rand -base64 64`
- [ ] Changer `POSTGRES_PASSWORD` (min 32 chars)
- [ ] Remplacer certificats SSL auto-signés par Let's Encrypt
- [ ] Configurer firewall (ufw/iptables) — ports 80, 443, 9090 (whitelist IP)
- [ ] Activer alertes Slack/Email dans `monitor_services.sh`
- [ ] Configurer backup externe (AWS S3 / remote SSH)
- [ ] Tester rollback sur staging
- [ ] Mettre en place Prometheus + Grafana (optionnel)
- [ ] Configurer log aggregation (ELK/Loki)
- [ ] Tester restore depuis backup
- [ ] Documenter Runbooks (runbooks incidents)
- [ ] Former équipe ops aux commandes Make

---

## 🐛 Dépannage rapide

### Backend ne répond pas
```bash
docker-compose logs backend
docker-compose restart backend
```

### DB inaccessible
```bash
docker ps | grep postgres
docker-compose exec db pg_isready -U postgres
```

### Jenkins build échoue
```bash
docker-compose logs jenkins
# Vérifier credentials Git dans Jenkins UI
```

### Espace disque manquant
```bash
docker system prune -a -f
find /var/backups/gps-field-assist -mtime +3 -delete
```

Voir [INFRASTRUCTURE.md](INFRASTRUCTURE.md#dépannage) pour plus.

---

## 📊 Résultats tests

| Test | Objectif | Résultat |
|------|----------|----------|
| Docker Compose up | Services en 60s | ✅ Validé |
| Pipeline Jenkins | Build + tests + APK | ✅ Validé |
| HTTPS redirect | HTTP→HTTPS | ✅ Validé |
| Backup auto | Quotidien, rotation | ✅ Validé |
| Monitoring | Logs + alertes | ✅ Validé |

**Tous les critères d'acceptation Sprint 7 complétés ✅**

---

## 🔜 Prochaines étapes

1. **Intégration Odoo complète** — synchronization bidirectionnelle tickets
2. **Monitoring avancé** — Prometheus + Grafana dashboards
3. **Scaling** — Docker Swarm / Kubernetes
4. **Backup externe** — AWS S3 / Google Cloud Storage
5. **CDN** — pour assets statiques (PDFs, images)
6. **WAF** — Web Application Firewall (ModSecurity)
7. **Log aggregation** — ELK stack ou Grafana Loki
8. **Secrets management** — HashiCorp Vault / AWS Secrets Manager

---

## 📞 Support

- **Documentation**: [INFRASTRUCTURE.md](INFRASTRUCTURE.md)
- **Sprint 7 LaTeX**: [sprint7_chapter.tex](sprint7_chapter.tex)
- **Encadrant**: M. Firas Salhi (Tunav IT Group)
- **Issues**: Créer une issue GitHub ou contacter l'équipe DevOps

---

## 📄 Licence

Propriétaire — Tunav IT Group © 2026

---

> **Sprint 7 terminé avec succès ✅** — Infrastructure DevOps complète, automatisée, sécurisée et prête pour la production.
