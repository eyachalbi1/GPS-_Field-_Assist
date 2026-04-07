# Fix GPS Modules & PDFs Loading - Progress Tracker

## Corrections appliquées ✅

### Backend — `backend/src/routes/files.py`
- [x] Ajout du champ `filename` dans `GET /api/files`
- [x] Ajout de la route `GET /api/files/download/{filename}` pour servir les PDFs

### Backend — `backend/start_server.bat`
- [x] Port changé de 8000 → 5000 (aligne avec IP publique 41.226.24.13:5000)

### Mobile — `mobile/lib/utils/config.dart`
- [x] `defaultIp` → `41.226.24.13`
- [x] `defaultPort` → `5000`

### Mobile — `mobile/lib/services/pdf_service.dart`
- [x] Correction du cast `as List` → gère `{files:[...]}` et `[...]`

### Mobile — `mobile/lib/screens/diagnostic_connection_screen.dart`
- [x] Port par défaut corrigé 8000 → 5000

### Mobile — `mobile/lib/screens/server_config_screen.dart`
- [x] Port par défaut corrigé 8000 → 5000 (×2)

## Actions requises

### 1. Redémarrer le serveur backend
```
cd backend
start_server.bat   (en tant qu'administrateur)
```

### 2. Vérifier les endpoints
```
curl http://41.226.24.13:5000/api/gps-devices
curl http://41.226.24.13:5000/api/files
curl http://41.226.24.13:5000/api/files/download/GPSTrackerManual-2016.pdf
```

### 3. Recompiler et relancer l'app Flutter
```
cd mobile
flutter run
```

**Status: Toutes les corrections appliquées → redémarrer le serveur → tester**
