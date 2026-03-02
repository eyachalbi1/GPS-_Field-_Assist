# 🚀 Guide de Test du Backend - Login

## 📋 Problème Actuel

Vous avez une erreur de connexion PostgreSQL. Voici comment la résoudre étape par étape.

## ✅ Solution Rapide (3 étapes)

### Étape 1: Configurer le mot de passe PostgreSQL

1. Ouvrez le fichier `.env`
2. Modifiez la ligne:
   ```
   DB_PASSWORD=votre_mot_de_passe_postgres
   ```
3. Remplacez par votre vrai mot de passe PostgreSQL

### Étape 2: Démarrer PostgreSQL et configurer la base

Double-cliquez sur: `setup_postgres.bat`

Ou en ligne de commande:
```bash
python setup_db.py
```

### Étape 3: Créer un utilisateur de test

```bash
python create_test_user.py
```

Cela créera:
- **Username:** tech1
- **Password:** password123
- **Role:** technicien

## 🧪 Tester le Login

### Démarrer le serveur:
```bash
python -m uvicorn main:app --reload --port 8000
```

### Dans un autre terminal, lancer les tests:
```bash
python test_login.py
```

Ou double-cliquez sur: `run_login_tests.bat`

## 📁 Fichiers Créés

| Fichier | Description |
|---------|-------------|
| `setup_db.py` | Diagnostic et configuration de PostgreSQL |
| `setup_postgres.bat` | Script Windows pour configurer PostgreSQL |
| `create_test_user.py` | Créer un utilisateur technicien de test |
| `test_login.py` | Tests automatisés du login |
| `run_login_tests.bat` | Lancer les tests facilement |
| `SETUP_GUIDE.md` | Guide détaillé de configuration |

## 🔍 Diagnostic des Problèmes

### PostgreSQL n'est pas démarré?

**Via Services Windows:**
1. `Win + R` → `services.msc`
2. Cherchez "postgresql"
3. Clic droit → Démarrer

**Via ligne de commande:**
```bash
net start postgresql-x64-14
```

### Mot de passe incorrect?

Testez manuellement:
```bash
psql -U postgres
```

Si ça demande un mot de passe, utilisez celui-ci dans le `.env`

### Base de données n'existe pas?

Le script `setup_db.py` la créera automatiquement.

## 📊 Résultats Attendus

Après configuration réussie, `test_login.py` devrait afficher:

```
============================================================
🚀 TESTS DE LOGIN BACKEND - GPS Field Assist
============================================================
✅ Serveur accessible

🧪 Test 1: Login avec identifiants valides
✅ Login réussi!
   Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   User: {'id': 2, 'username': 'tech1', 'role': 'technicien'}

🧪 Test 2: Login avec mot de passe incorrect
✅ Rejet correct des identifiants invalides

🧪 Test 3: Login avec utilisateur inexistant
✅ Rejet correct de l'utilisateur inexistant

🧪 Test 4: Login avec champs vides
   Status: 401

============================================================
✅ Tests terminés
============================================================
```

## 🆘 Besoin d'Aide?

1. Consultez `SETUP_GUIDE.md` pour plus de détails
2. Vérifiez que PostgreSQL est installé: `psql --version`
3. Vérifiez les logs du serveur pour plus d'informations

## 🎯 Prochaines Étapes

Une fois le login fonctionnel:
1. Intégrer l'API dans l'application mobile Flutter
2. Tester la synchronisation avec Odoo
3. Implémenter les autres endpoints (tâches, SMS, etc.)
