# 🔧 Guide de Correction - Erreur de Connexion Serveur

## Diagnostic Effectué

### Serveur Backend ✅
- Serveur FastAPI démarré sur port 8000
- Base de données PostgreSQL connectée
- API fonctionnelle

### Application Mobile ✅
- Configuration dynamique de l'URL du serveur
- Écran de diagnostic de connexion disponible
- Support des tentatives de reconnexion

---

## Solutions Possibles

### Solution 1: Vérifier l'IP du PC

1. Ouvrez **cmd** sur votre PC
2. Tapez: `ipconfig`
3. Cherchez **Adresse IPv4** (ex: 192.168.1.x)
4. Notez cette adresse

### Solution 2: Configurer le Serveur sur le Mobile

1. Ouvrez l'application GPS Field Assist
2. Allez dans **Diagnostique** → **Configuration Serveur**
3. Entrez l'IP de votre PC (celle obtenue en Solution 1)
4. Cliquez sur **Sauvegarder**

### Solution 3: Vérifier le Pare-feu Windows

1. Ouvrez **Pare-feu Windows**
2. Autoriser une application à travers le pare-feu
3. Ajoutez **Python** (python.exe) à la liste

### Solution 4: Tester la Connexion

1. Dans l'app, allez dans **Diagnostique**
2. Cliquez sur **Tester la connexion**
3. Vérifiez les résultats

---

## Commandes Utiles

### Démarrer le serveur:
```
bash
cd backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

### Vérifier si le serveur est joignable:
```
powershell
Invoke-WebRequest -Uri http://localhost:8000/api/auth/users
```

### Vérifier la base de données:
```
bash
cd backend
python test_db_connection.py
```

---

## Dépannage

| Problème | Solution |
|----------|----------|
| "Timeout serveur injoignable" | Vérifier IP et pare-feu |
| "Connexion refusée" | Serveur non démarré |
| "Network unreachable" | Mauvais réseau WiFi |
| "401 Unauthorized" | Mauvais identifiants |

---

## Identifiants de Test

- **Utilisateur:** tech1
- **Mot de passe:** tech123
