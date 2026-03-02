# 🚀 DÉMARRAGE RAPIDE - Test Backend Login

## ⚡ Solution en 2 clics

### 1️⃣ Configurer le mot de passe PostgreSQL
```
Double-cliquez sur: fix_password.bat
```
- Entrez votre mot de passe PostgreSQL
- Le script teste automatiquement la connexion
- ✅ Si succès, passez à l'étape 2

### 2️⃣ Configuration automatique
```
Double-cliquez sur: start_here.bat
Choisissez l'option 5
```
- Crée la base de données
- Crée l'utilisateur de test (tech1 / password123)
- ✅ Configuration terminée !

### 3️⃣ Tester le backend
```
Dans start_here.bat:
- Option 3: Démarrer le serveur
- Option 4: Tester le login (dans un autre terminal)
```

---

## 🆘 Problème: "connection to server failed"

### PostgreSQL n'est pas démarré

**Solution rapide:**
1. Appuyez sur `Win + R`
2. Tapez `services.msc`
3. Cherchez "postgresql"
4. Clic droit → Démarrer

**Ou en ligne de commande:**
```bash
net start postgresql-x64-14
```

---

## 📋 Résumé des fichiers

| Fichier | Quand l'utiliser |
|---------|------------------|
| **fix_password.bat** | ⭐⭐⭐ COMMENCEZ ICI - Configure le mot de passe |
| **start_here.bat** | ⭐⭐ Menu principal - Tout configurer |
| **HELP.bat** | ⭐ Affiche l'aide rapide |
| setup_db.py | Configuration manuelle de la DB |
| create_test_user.py | Créer utilisateur test |
| test_login.py | Tests automatisés |

---

## ✅ Checklist

- [ ] PostgreSQL installé et démarré
- [ ] Mot de passe configuré (fix_password.bat)
- [ ] Base de données créée (start_here.bat option 5)
- [ ] Utilisateur test créé (tech1 / password123)
- [ ] Serveur démarré (start_here.bat option 3)
- [ ] Tests réussis (start_here.bat option 4)

---

## 🎯 Identifiants de test

**Technicien:**
- Username: `tech1`
- Password: `password123`

**Admin:**
- Username: `admin`
- Password: `admin123`

---

**Besoin d'aide?** Consultez TEST_LOGIN_README.md ou TOOLS_SUMMARY.md
