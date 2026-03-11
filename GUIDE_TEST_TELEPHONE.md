# GUIDE DE TEST SUR TÉLÉPHONE RÉEL

## Prérequis
- PC et téléphone sur le **même réseau WiFi**
- Serveur backend installé et démarré
- Application mobile installée sur le téléphone

## ÉTAPE 1 : Trouver l'IP du PC

### Méthode 1 : Commande rapide
```cmd
ipconfig | findstr "IPv4"
```

### Méthode 2 : Interface graphique
1. Ouvrir **Paramètres Windows** > **Réseau et Internet**
2. Cliquer sur **Propriétés** de votre connexion WiFi
3. Chercher **Adresse IPv4** (exemple: 192.168.1.100)

### Méthode 3 : Script automatique
Exécuter `get_ip.bat` (voir ci-dessous)

## ÉTAPE 2 : Configurer le pare-feu Windows

### Option A : Désactiver temporairement (pour test uniquement)
1. Panneau de configuration > Pare-feu Windows
2. Désactiver pour réseau privé

### Option B : Autoriser le port 8000 (recommandé)
```cmd
netsh advfirewall firewall add rule name="GPS Field Assist" dir=in action=allow protocol=TCP localport=8000
```

## ÉTAPE 3 : Démarrer le serveur

### Avec le service Windows (recommandé)
```cmd
net start GPSFieldAssist
```

### Ou manuellement
```cmd
cd backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

## ÉTAPE 4 : Vérifier que le serveur est accessible

### Depuis le PC
Ouvrir dans le navigateur : http://localhost:8000

### Depuis le téléphone
1. Connecter le téléphone au **même WiFi** que le PC
2. Ouvrir le navigateur du téléphone
3. Aller sur : http://[IP_DU_PC]:8000
   - Exemple : http://192.168.1.100:8000
4. Vous devriez voir : `{"status":"ok","message":"GPS Field Assist Server is running"}`

## ÉTAPE 5 : Configurer l'application mobile

### Dans l'application mobile :
1. Ouvrir l'application
2. Sur l'écran de login, cliquer sur l'icône **paramètres** (⚙️)
3. Entrer l'IP du PC : `192.168.1.100` (votre IP)
4. Port : `8000`
5. Sauvegarder

### Identifiants de test
- Username : `technicien1`
- Password : `tech2024`

## ÉTAPE 6 : Tester la connexion

1. Lancer l'application mobile
2. Se connecter avec les identifiants
3. Vérifier que les tâches s'affichent

## Dépannage

### ❌ "Impossible de se connecter au serveur"
- Vérifier que PC et téléphone sont sur le même WiFi
- Vérifier l'IP du PC (elle peut changer)
- Vérifier que le serveur est démarré : `check_server.bat`
- Désactiver temporairement le pare-feu Windows

### ❌ "Connection timeout"
- Vérifier le pare-feu Windows (port 8000)
- Vérifier que le serveur écoute sur 0.0.0.0 (pas 127.0.0.1)

### ❌ "Connection refused"
- Le serveur n'est pas démarré
- Exécuter : `net start GPSFieldAssist`

### ❌ L'IP change à chaque redémarrage
Configurer une IP statique :
1. Paramètres Windows > Réseau
2. Propriétés de la connexion WiFi
3. Modifier les paramètres IP > Manuel
4. Définir une IP fixe (ex: 192.168.1.100)

## URLs de test

- Health check : http://[IP_DU_PC]:8000/health
- API docs : http://[IP_DU_PC]:8000/docs
- Login : http://[IP_DU_PC]:8000/api/auth/login

## Commandes utiles

### Voir les connexions actives
```cmd
netstat -an | findstr :8000
```

### Tester depuis le PC
```cmd
curl http://localhost:8000/health
```

### Logs du serveur
```cmd
type backend\logs\service_output.log
```

## Notes importantes

⚠️ **Sécurité** : Cette configuration est pour test uniquement
⚠️ **Réseau** : PC et téléphone doivent être sur le même réseau local
⚠️ **IP dynamique** : L'IP peut changer, vérifier régulièrement
⚠️ **Pare-feu** : Autoriser le port 8000 dans le pare-feu Windows
