# 🔧 CORRECTION - Serveur Injoignable sur Login

## Problème
L'application mobile affiche "Serveur injoignable!" sur la page de login.

---

## Étape 1: Diagnostiquer le problème

### 1.1 Lancer le diagnostic automatique
```
Allez dans le dossier backend et double-cliquez sur:
diagnostic_total.bat
```

Cela va:
- Détecter votre adresse IP locale
- Vérifier si le serveur fonctionne
- Tester la connexion à la base de données

### 1.2 Résultat attendu
```
[INFO] IP locale du PC: 192.168.x.x
[INFO] Utilisez cette IP dans l'application mobile!
[TEST 1] Connexion au serveur local...
  ✓ Serveur accessible: Status 200
[TEST 2] Test de l'API /api/auth/login...
  ✓ Connexion réussie avec: admin
```

---

## Étape 2: Démarrer le serveur

Si le serveur n'est pas démarré:

1. Allez dans le dossier `backend`
2. Double-cliquez sur `start_server.bat`
3. Attendez que le message "Uvicorn running on http://0.0.0.0:8000" apparaisse

---

## Étape 3: Configurer le pare-feu

Pour que le mobile puisse accéder au serveur:

1. Double-cliquez sur `configure_firewall.bat`
2. Autorisez Python et le port 8000
3. Cliquez sur "Autoriser l'accès" si demandé

---

## Étape 4: Configurer l'application mobile

### 4.1 Trouver votre IP
Ouvrez cmd et tapez:
```
ipconfig
```
Cherchez "Adresse IPv4" (ex: 192.168.1.100)

### 4.2 Configurer dans l'app
1. Ouvrez l'application GPS Field Assist
2. Allez dans **Diagnostique**
3. Cliquez sur **Configuration Serveur**
4. Entrez votre IP (ex: 192.168.1.100)
5. Laissez le port: 8000
6. Cliquez sur **Sauvegarder**

### 4.3 Tester la connexion
1. Allez dans **Diagnostique** → **Test connexion**
2. Cliquez sur "Tester la connexion"
3. Vérifiez que tout est OK

---

## Étape 5: Se connecter

1. Revenez à l'écran de login
2. Entrez les identifiants:
   - **Utilisateur:** admin
   - **Mot de passe:** admin123
3. Cliquez sur "Se connecter"

---

## Dépannage

### Problème: "Timeout serveur injoignable"
- ✓ Le serveur n'est pas démarré → Démarrez start_server.bat
- ✓ Mauvaise IP → Vérifiez avec ipconfig
- ✓ Pare-feu bloque → Exécutez configure_firewall.bat

### Problème: "Connexion refusée"
- ✓ Le serveur n'écoute pas sur le réseau → Vérifiez --host 0.0.0.0
- ✓ Port occupé → Changez le port dans start_server.bat

### Problème: "Network unreachable"
- ✓ Mobile pas sur le même WiFi → Vérifiez le WiFi
- ✓ Routeur bloque les connexions → Vérifiez le routeur

---

## Fichiers créés pour le diagnostic

| Fichier | Description |
|---------|-------------|
| `diagnostic_total.bat` | Lance le diagnostic complet |
| `diagnostic_reseau.bat` | Vérifie le réseau et l'IP |
| `configure_firewall.bat` | Configure le pare-feu |
| `test_server_status.py` | Teste le serveur et l'API |

---

## Commandes utiles

### Démarrer le serveur:
```bash
cd backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

### Tester manuellement:
```bash
curl http://localhost:8000/
curl -X POST http://localhost:8000/api/auth/login -H "Content-Type: application/json" -d "{\"username\":\"admin\",\"password\":\"admin123\"}"
```

---

## Identifiants par défaut

| Rôle | Utilisateur | Mot de passe |
|------|-------------|--------------|
| Admin | admin | admin123 |
| Technicien | tech1 | tech123 |
| Technicien | tech2 | tech123 |

---

## Résumé des étapes

```
1. [PC] Lancez diagnostic_total.bat
2. [PC] Notez l'IP affichée
3. [PC] Démarrez start_server.bat
4. [PC] Exécutez configure_firewall.bat
5. [Mobile] Configurez l'IP dans l'app
6. [Mobile] Testez la connexion
7. [Mobile] Connectez-vous!
```

