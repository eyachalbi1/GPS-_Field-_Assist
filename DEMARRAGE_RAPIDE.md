# 🚀 Démarrage Rapide - GPS Field Assist Mobile

## ⚡ En 5 Minutes

### 1️⃣ Vérifier les Prérequis (1 min)
```bash
# Vérifier Flutter
flutter --version

# Vérifier les appareils connectés
flutter devices
```

### 2️⃣ Compiler l'Application (3 min)
```bash
cd mobile
flutter build apk --debug
```

### 3️⃣ Installer sur le Téléphone (1 min)
```bash
flutter install
```

### 4️⃣ Lancer l'Application
```bash
flutter run
```

---

## 🔐 Connexion

**Identifiants:**
```
Username: tech1
Password: password123
```

---

## 🎯 Que Peut-on Faire ?

### ✅ Voir les Modules GPS
- **ASSETS** → Grille de modules avec photos
- Toutes les images s'affichent maintenant !

### ✅ Configurer les Modules
- **DIAGNOSTIQUE** → Configuration
- Remplir IMEI, Description, Numéro de téléphone
- Envoyer SMS pour tester la communication

### ✅ Consulter les Manuels
- **Deux façons** pour accéder aux PDFs :
  1. Depuis ASSETS → Cliquer sur "Manuel d'utilisation"
  2. Depuis DIAGNOSTIQUE → Icône PDF rouge → Liste complète

### ✅ Télécharger les PDFs
- **PDF Download Screen** :
  - Liste de tous les PDFs disponibles
  - Bouton "Télécharger" pour chaque PDF
  - Fichiers sauvegardés dans Downloads

---

## 📱 Navigation Principale

```
┌─────────────────┐
│  LOGIN SCREEN   │
│  (tech1 /...)   │
└────────┬────────┘
         │
    ┌────▼────┐
    │ HOME    │
    │ SCREEN  │
    └──┬──┬───┘
       │  │     Barre latérale
       │  └──────────────┐
       │                 │
    ┌──▼────┐    ┌──────▼──┐    ┌────────────┐
    │ TO DO  │    │ ASSETS  │    │ DIAGNOSTIC │
    └────────┘    └─────────┘    └───┬────────┘
                                      │
                         ┌────────────┼────┐
                         │            │    │
                    ┌────▼───┐  ┌─────▼──┐┌──▼────┐
                    │Firmware│  │ Config ││Diag.  │
                    └────────┘  └────┬───┘└───────┘
                                     │
                        ┌────────────▼─────┐
                        │ PDF DOWN SCREEN  │
                        └──────────────────┘
```

---

## 🎨 Changements Majeurs

### ✨ Photos des Modules
- **Avant:** Seulement 2 colonnes, certaines photos manquantes
- **Après:** Grille adaptative, toutes les photos visibles

### ✨ Écran Configuration
- **Avant:** 3 boutons (SMS, PDF, Télécharger PDF)
- **Après:** 2 boutons (SMS, Consulter PDF) + écran épuré

### ✨ Téléchargement PDF
- **Avant:** Pas d'écran dédié
- **Après:** Écran complet avec tous les PDFs, actions claires

---

## 🔧 Configuration Réseau

**Serveur Backend:**
```
URL: http://192.168.0.2:8000
Port: 8000
```

**Mobile Config File:**
```dart
// mobile/lib/utils/config.dart
static const String baseUrl = 'http://192.168.0.2:8000';
```

**Prérequis:**
- Téléphone et PC sur le **même Wi-Fi**
- Serveur backend démarré
- Port 8000 accessible

---

## 🎬 Scénarios de Test Rapides

### Scénario 1: Voir les Photos (2 min)
1. Connexion (tech1/password123)
2. Cliquez ASSETS
3. ✅ Vérifiez que toutes les photos s'affichent

### Scénario 2: Configurer un Module (3 min)
1. Cliquez DIAGNOSTIQUE
2. Sélectionnez Configuration
3. Cliquez sur un module
4. Remplissez les champs
5. Envoyez un SMS
6. ✅ Vérifiez que SMS s'ouvre

### Scénario 3: Télécharger Un PDF (2 min)
1. Cliquez DIAGNOSTIQUE
2. Cliquez sur l'icône PDF rouge
3. Cliquez "Télécharger" sur un PDF
4. ✅ Vérifiez que le fichier est dans Downloads

### Scénario 4: Consulter Un PDF (2 min)
1. Allez sur ASSETS
2. Cliquez sur un module
3. Cliquez "Manuel d'utilisation (PDF)"
4. ✅ Vérifiez que le PDF s'ouvre et défile

---

## 🌐 URLs Utiles

| Service | URL | Statut |
|---------|-----|--------|
| Application Mobile | http://192.168.0.2:8000 | ✅ Démarrée |
| API Auth | http://192.168.0.2:8000/api/auth | ✅ OK |
| API Files | http://192.168.0.2:8000/api/files | ✅ OK |
| Docs API | http://192.168.0.2:8000/docs | ✅ OK |

---

## 🛠️ Commandes Utiles

```bash
# Nettoyer et reconstruire
flutter clean
flutter pub get
flutter build apk

# Analyser le code
flutter analyze

# Tester sur device
flutter run

# Mode debug
flutter run -v

# Build APK release
flutter build apk --release

# Installer sur device spécifique
flutter install -d <device_id>
```

---

## 📊 Fichiers Importants

```
projet/
├── mobile/
│   ├── lib/
│   │   ├── screens/
│   │   │   ├── assets_screen.dart ✅ MODIFIÉ
│   │   │   ├── config_screen.dart ✅ MODIFIÉ
│   │   │   ├── diagnostic_screen.dart ✅ MODIFIÉ
│   │   │   ├── pdf_download_screen.dart ✨ NOUVEAU
│   │   │   └── pdf_viewer_screen.dart
│   │   └── utils/
│   │       └── config.dart (Configuration réseau)
│   └── pubspec.yaml
│
└── backend/
    ├── main.py
    ├── start_server.bat
    └── setup.bat
```

---

## ✅ Avant de Commencer

- [ ] Backend démarré (`start_server.bat`)
- [ ] Téléphone connecté au réseau
- [ ] Flutter installé et à jour
- [ ] Pas de soucis de compilation (`flutter analyze`)

---

## 🎯 Objectifs Réalisés

✅ Photos visibles dans les cartes Assets
✅ Écran Configuration épuré (sans téléchargement PDF)
✅ Téléchargement PDF centralisé et organisé
✅ Accès rapide aux PDFs depuis Diagnostique
✅ Interface intuitive et responsive

---

## 🚀 Prêt à Démarrer ?

```bash
cd mobile
flutter run
```

**Bienvenue dans GPS Field Assist! 👋**

---

## 💡 Astuce: Raccourcis Clavier

- `r` - Hot Reload (recharger l'app sans redémarrer)
- `R` - Hot Restart (redémarrer l'app)
- `q` - Quitter (arrêter le serveur debug)
- `p` - Afficher/masquer la performance overlay
- `w` - Afficher le widget inspector

---

## 📞 Support Rapide

**App ne compile pas?**
```bash
flutter clean
flutter pub get
flutter build apk
```

**Photos ne s'affichent pas?**
- Vérifier `assets/modules_gps/` existe
- Vérifier `pubspec.yaml` les liste

**Connexion échoue?**
- Vérifier serveur démarré
- Vérifier même réseau Wi-Fi
- Vérifier IP dans `config.dart`

---

**Version:** 1.0.0
**Dernière mise à jour:** 23 Février 2026
**Statut:** ✅ Production Ready