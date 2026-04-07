# GUIDE: CONFIGURER UNE IP FIXE POUR LE SERVEUR

## 🚀 Option 0: Script Automatique (Recommandé)

**`auto_ip_setup.bat`** fait tout automatiquement:

1. **Détecte IP** avec `ipconfig | findstr "IPv4"`
2. **Option IP fixe** (netsh, admin requis)
3. **Ouvre pare-feu** port 8000
4. **Démarre serveur** sur `0.0.0.0:8000`
5. **Affiche URL mobile**: `http://VOTRE_IP:8000`

```
cd backend
auto_ip_setup.bat  (clic droit "Exécuter en tant qu'admin")
```

**Test**: `http://IP_AFFICHEE:8000/health`

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

3. **App mobile**: IP/port dynamique via Paramètres (déjà configuré, fallback fixe corrigé)




## Recommandation finale

1. **Exécuter** `backend/auto_ip_setup.bat` (admin) ✅
2. **Configurer IP mobile** via app Paramètres avec IP affichée
3. **Tester** `http://IP:8000/health` (téléphone)
4. **Service 24/7**: `install_service.bat`

