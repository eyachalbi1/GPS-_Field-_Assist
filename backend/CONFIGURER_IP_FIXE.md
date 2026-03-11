# GUIDE: CONFIGURER UNE IP FIXE POUR LE SERVEUR

## Pourquoi une IP fixe ?

Actuellement, votre serveur utilise l'IP dynamique `41.226.24.13` qui peut changer. 
Pour que l'application mobile fonctionne toujours, vous devez configurer une IP fixe.

## Option 1: IP Statique sur Windows (Recommandé)

### Étape 1: Trouver votre configuration actuelle

1. Ouvrir **Invite de commandes** (cmd)
2. Taper: `ipconfig /all`
3. Noter:
   - **Adresse IPv4**: (ex: 41.226.24.13)
   - **Masque de sous-réseau**: (ex: 255.255.255.0)
   - **Passerelle par défaut**: (ex: 41.226.24.1)
   - **Serveur DNS**: (ex: 8.8.8.8)

### Étape 2: Configurer l'IP statique

1. Ouvrir **Panneau de configuration** > **Centre Réseau et partage**
2. Cliquer sur votre connexion réseau active
3. Cliquer sur **Propriétés**
4. Sélectionner **Protocole Internet version 4 (TCP/IPv4)**
5. Cliquer sur **Propriétés**
6. Cocher **Utiliser l'adresse IP suivante**
7. Entrer:
   - **Adresse IP**: `41.226.24.13` (ou l'IP que vous voulez fixer)
   - **Masque de sous-réseau**: `255.255.255.0`
   - **Passerelle par défaut**: `41.226.24.1`
   - **Serveur DNS préféré**: `8.8.8.8`
   - **Serveur DNS auxiliaire**: `8.8.4.4`
8. Cliquer sur **OK**

### Étape 3: Vérifier la configuration

```cmd
ipconfig
ping 8.8.8.8
```

## Option 2: Réservation DHCP sur le routeur (Plus simple)

1. Se connecter à l'interface web du routeur (ex: http://192.168.1.1)
2. Aller dans **DHCP** > **Réservation d'adresse**
3. Trouver votre PC dans la liste des appareils connectés
4. Réserver l'IP actuelle pour l'adresse MAC de votre PC
5. Le routeur donnera toujours la même IP à votre PC

## Option 3: Utiliser un nom de domaine local (Alternative)

Si vous ne pouvez pas fixer l'IP, utilisez le nom d'hôte du PC:

1. Trouver le nom du PC: `hostname`
2. Dans l'app mobile, utiliser: `http://NOM-DU-PC:8000`

## Configuration du pare-feu Windows

Pour que le serveur soit accessible depuis le réseau:

```cmd
netsh advfirewall firewall add rule name="GPS Field Assist Server" dir=in action=allow protocol=TCP localport=8000
```

Ou exécuter: `configure_firewall.bat`

## Vérification finale

1. Sur le PC serveur:
   ```cmd
   ipconfig
   ```
   Noter l'IP fixe

2. Depuis un autre appareil sur le même réseau:
   ```
   http://[IP_FIXE]:8000/health
   ```
   Devrait retourner: `{"status":"healthy","service":"GPS Field Assist"}`

3. Mettre à jour l'IP dans l'app mobile:
   - Fichier: `mobile/lib/services/gps_device_service.dart`
   - Ligne: `static const String apiUrl = 'http://41.226.24.13:5000/api/gps-devices';`
   - Remplacer par votre IP fixe

## IP actuelle dans l'application

L'application mobile utilise actuellement:
- **API GPS Devices**: `http://41.226.24.13:5000/api/gps-devices`
- **Port serveur**: `8000` (mais l'app utilise le port 5000 ❌)

⚠️ **ATTENTION**: Il y a une incohérence de port!
- Le serveur tourne sur le port **8000**
- L'app mobile cherche sur le port **5000**

## Correction nécessaire

Choisir l'une des options:

### Option A: Changer le port du serveur à 5000
Dans `start_server.bat`, remplacer:
```
--port 8000
```
par:
```
--port 5000
```

### Option B: Changer le port dans l'app mobile
Dans `mobile/lib/services/gps_device_service.dart`, remplacer:
```dart
static const String apiUrl = 'http://41.226.24.13:5000/api/gps-devices';
```
par:
```dart
static const String apiUrl = 'http://41.226.24.13:8000/api/gps-devices';
```

## Recommandation finale

1. **Fixer l'IP** à `41.226.24.13` (Option 1 ou 2)
2. **Utiliser le port 8000** (Option B ci-dessus)
3. **Configurer le pare-feu** pour autoriser le port 8000
4. **Tester** depuis l'app mobile
