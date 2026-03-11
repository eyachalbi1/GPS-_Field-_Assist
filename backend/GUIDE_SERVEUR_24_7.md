# GUIDE DE DÉMARRAGE SERVEUR 24/7

## Installation du service Windows (Une seule fois)

1. **Clic droit** sur `install_service_24_7.bat`
2. Sélectionner **"Exécuter en tant qu'administrateur"**
3. Attendre la fin de l'installation
4. Le serveur démarre automatiquement

## Vérification du serveur

Exécuter `check_server.bat` pour vérifier l'état du serveur

## Commandes utiles

### Démarrer le service
```cmd
net start GPSFieldAssist
```

### Arrêter le service
```cmd
net stop GPSFieldAssist
```

### Redémarrer le service
```cmd
net stop GPSFieldAssist && net start GPSFieldAssist
```

### Voir les logs
```cmd
type logs\service_output.log
type logs\service_error.log
```

### Désinstaller le service
```cmd
nssm remove GPSFieldAssist confirm
```

## Fonctionnalités 24/7

✅ **Démarrage automatique** au démarrage de Windows
✅ **Redémarrage automatique** en cas d'erreur (délai: 5 secondes)
✅ **Logs automatiques** dans le dossier `logs/`
✅ **Surveillance** avec le script `check_server.bat`

## URLs d'accès

- Local: http://localhost:8000
- Réseau: http://[IP_DU_PC]:8000
- Health check: http://localhost:8000/health

## Trouver l'IP du PC

```cmd
ipconfig
```
Chercher "Adresse IPv4" dans la section de votre connexion réseau

## Dépannage

### Le service ne démarre pas
1. Vérifier que PostgreSQL est démarré
2. Vérifier les logs: `type logs\service_error.log`
3. Vérifier la configuration dans `.env`

### Le serveur ne répond pas
1. Exécuter `check_server.bat`
2. Redémarrer: `net stop GPSFieldAssist && net start GPSFieldAssist`
3. Vérifier le pare-feu Windows (port 8000)

### Modifier la configuration
```cmd
nssm edit GPSFieldAssist
```
