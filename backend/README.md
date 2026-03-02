# GPS Field Assist - Backend

## 🚀 Démarrage

### 1. Créer la base PostgreSQL
```bash
psql -U postgres
CREATE DATABASE tunav_gps_tracking_db;
\q
```

### 2. Démarrer le serveur
```bash
python -m uvicorn main:app --reload --port 8000
```

## 👨‍💼 Gestion des Techniciens (Admin)

```bash
# Ajouter un technicien
python admin_postgres.py add

# Lister les techniciens
python admin_postgres.py list

# Supprimer un technicien
python admin_postgres.py delete
```

## 🧪 Tester le Login

```bash
python test_simple_login.py
```

## 📡 API Endpoint

**Login:** `POST http://localhost:8000/api/auth/login`

**Body:**
```json
{
  "username": "tech1",
  "password": "123456"
}
```

**Response:**
```json
{
  "token": "eyJ0eXAi...",
  "user": {
    "id": 1,
    "username": "tech1",
    "role": "technicien"
  }
}
```