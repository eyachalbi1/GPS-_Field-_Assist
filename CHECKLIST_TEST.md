# ✅ Checklist de Vérification de l'Application Mobile

## 🎯 Avant de Déployer

### Vérifications Générales
- [ ] Code compilé sans erreurs (sauf avertissements)
- [ ] `flutter pub get` exécuté avec succès
- [ ] `flutter analyze` réalisé avec succès
- [ ] Aucune erreur critique détectée

### Vérifications du Backend
- [ ] Serveur FastAPI démarré (`http://192.168.0.2:8000`)
- [ ] PostgreSQL fonctionnel
- [ ] Base de données `tunav_gps` créée
- [ ] Utilisateur de test créé (`tech1 / password123`)
- [ ] API `/api/auth/login` fonctionnelle
- [ ] CORS configuré correctement

### Vérifications de la Configuration Réseau
- [ ] IP locale: `192.168.0.2`
- [ ] Port serveur: `8000`
- [ ] Firewall port 8000 ouvert (si Windows)
- [ ] Téléphone et PC sur le même réseau Wi-Fi

---

## 📱 Test sur Téléphone Réel

### Phase 1: Installation
1. [ ] APK constructible (`flutter build apk`)
2. [ ] APK installable sur le téléphone
3. [ ] Application démarre sans crash
4. [ ] Écran de login s'affiche

### Phase 2: Authentication
1. [ ] Connexion avec `tech1 / password123` réussit
2. [ ] Redirection vers l'écran d'accueil
3. [ ] Pas de message d'erreur d'authentification
4. [ ] Token reçu et sauvegardé

### Phase 3: Navigation
1. [ ] Barre latérale affiche les 3 sections
2. [ ] Clic sur "TO DO" bascule vers les tâches
3. [ ] Clic sur "ASSETS" bascule vers les modules
4. [ ] Clic sur "DIAGNOSTIQUE" bascule vers diagnostic

### Phase 4: Assets (Modules)
1. [ ] Tous les modules affichés dans une grille
2. [ ] Les photos des modules s'affichent
3. [ ] Plus de 2 colonnes sur l'écran (adaptatif)
4. [ ] Noms des modules lisibles
5. [ ] IMEI des modules affichés
6. [ ] Recherche fonctionne (filtrage par nom/IMEI)
7. [ ] Clic sur une carte ouvre les détails

### Phase 5: Détails du Module (Assets)
1. [ ] Photo agrandie du module
2. [ ] Description visible
3. [ ] IMEI affiché
4. [ ] Caractéristiques listées
5. [ ] Bouton "Manuel d'utilisation (PDF)" présent
6. [ ] Clic sur le PDF ouvre le lecteur
7. [ ] Les pages du PDF sont consultables
8. [ ] Bouton fermer ferme le dialog

### Phase 6: Section Diagnostique - Configuration
1. [ ] Écran affiche la liste des modules
2. [ ] Sélectionnez "Configuration" dans les onglets
3. [ ] Cliquez sur "Ouvrir" d'un module
4. [ ] Écran ConfigScreen s'ouvre
5. [ ] Les 3 champs texte sont visibles:
   - [ ] Numéro IMEI
   - [ ] Description
   - [ ] Numéro de téléphone
6. [ ] Deux boutons sont visibles:
   - [ ] Envoyer SMS
   - [ ] Consulter le Manuel (PDF)
7. [ ] Le bouton "Télécharger PDF" n'est PAS visible ✅

### Phase 7: Fonctionnalités SMS
1. [ ] Entrez un numéro de téléphone valide
2. [ ] Cliquez sur "Envoyer SMS"
3. [ ] L'application SMS s'ouvre
4. [ ] Le numéro est pré-rempli
5. [ ] Vous pouvez composer et envoyer

### Phase 8: PDFs - Écran Diagnostic
1. [ ] Icône PDF rouge visible dans la barre d'outils
2. [ ] Clic sur l'icône ouvre PdfDownloadScreen
3. [ ] Liste de 4 PDFs affichée:
   - [ ] GPS Tracker Manual
   - [ ] EasyCan Instructions
   - [ ] EasyCan Digital Manual
   - [ ] Module 5227793
4. [ ] Chaque PDF a deux boutons:
   - [ ] "Voir" (bleu)
   - [ ] "Télécharger" (vert)

### Phase 9: Téléchargement de PDFs
1. [ ] Cliquez sur "Télécharger" pour un PDF
2. [ ] Message "Téléchargement en cours..." s'affiche
3. [ ] Message de confirmation avec le chemin
4. [ ] Le fichier est sauvegardé localement
5. [ ] Vérifiez dans le dossier Downloads

### Phase 10: Lecture de PDFs
1. [ ] Cliquez sur "Voir" pour un PDF
2. [ ] Le lecteur PDF s'ouvre en fullscreen
3. [ ] Les pages sont défilables
4. [ ] Le zoom fonctionne (pinch-to-zoom)
5. [ ] Bouton fermer ferme le lecteur

### Phase 11: Tasks (TO DO)
1. [ ] Liste des tâches s'affiche
2. [ ] Les tâches sont colorées par statut
3. [ ] Clic sur une tâche ouvre les détails
4. [ ] Vous pouvez verifier les photos associées

### Phase 12: Erreurs et Messages
1. [ ] Les erreurs de connexion s'affichent
2. [ ] Les messages de succès s'affichent
3. [ ] Les SnackBars s'affichent correctement
4. [ ] Pas de crash lors de la navigation

---

## 🎨 Vérifications Visuelles

### Écran d'Accueil
- [ ] Logo Tunav visible
- [ ] Barre latérale présente
- [ ] Fond d'écran correct
- [ ] Interface responsive

### Assets Screen
- [ ] Grille avec colonnes adaptatif
- [ ] Photos visibles et bien alignées
- [ ] Texte lisible
- [ ] Barre de recherche fonctionnelle

### Config Screen
- [ ] Titre "Configuration du module" visible
- [ ] Section "Communication SMS" claire
- [ ] Champs bien espacés
- [ ] Boutons bien positionnés
- [ ] Pas de bouton de téléchargement ❌

### PDF Download Screen
- [ ] Liste des PDFs claire
- [ ] Icônes PDF rouges visibles
- [ ] Boutons "Voir" et "Télécharger" distincts
- [ ] Layout responsive

---

## 🔧 Vérifications Techniques

### Performance
- [ ] L'application ne freeze pas
- [ ] La navigation est fluide
- [ ] Les photos chargent rapidement
- [ ] Les PDFs s'ouvrent sans délai excessif

### Stockage
- [ ] Les PDFs téléchargés occupent la bonne place
- [ ] Pas d'erreur d'espace disque
- [ ] Les fichiers sont persistants

### Connectivité
- [ ] La connexion au serveur est stable
- [ ] Les timeouts sont gérés proprement
- [ ] Les erreurs réseau affichent des messages
- [ ] La déconnexion est gérée

---

## 🐛 Problèmes Connus et Solutions

### Photos ne s'affichent pas
- [ ] Vérifier que les images sont dans `assets/modules_gps/`
- [ ] Vérifier que `pubspec.yaml` les liste
- [ ] Redémarrer l'application
- [ ] Nettoyer le build: `flutter clean`

### PDFs ne s'ouvrent pas
- [ ] Vérifier que les PDFs sont dans `pdfs_modules/`
- [ ] Vérifier que `pubspec.yaml` les liste
- [ ] Vérifier les permissions de l'application

### Connexion serveur échoue
- [ ] Vérifier que le serveur est démarré
- [ ] Vérifier que le téléphone est sur le même réseau
- [ ] Vérifier l'IP dans `config.dart`
- [ ] Vérifier le firewall

### SMS ne s'envoie pas
- [ ] Vérifier le numéro de téléphone
- [ ] Vérifier que l'application SMS est disponible
- [ ] Vérifier les permissions SMS

---

## 📊 Résumé Fonctionnel

| Fonctionnalité | ✅ OK | ⚠️ À Tester | ❌ Ne fonctionne pas |
|---|---|---|---|
| Photos Assets | [ ] | [ ] | [ ] |
| Grille Responsive | [ ] | [ ] | [ ] |
| Configuration SMS | [ ] | [ ] | [ ] |
| Consultation PDF | [ ] | [ ] | [ ] |
| Téléchargement PDF | [ ] | [ ] | [ ] |
| Authentification | [ ] | [ ] | [ ] |
| Navigation | [ ] | [ ] | [ ] |
| Recherche | [ ] | [ ] | [ ] |

---

## ✅ Signature de Test

**Date du Test:** _______________

**Testeur:** _______________

**Téléphone:** _______________

**Résultat Global:**
- [ ] ✅ PASS - Prêt pour production
- [ ] ⚠️ PASS CONDITONNEL - Quelques petites corrections
- [ ] ❌ FAIL - Retour en développement

**Commentaires:**

```
_____________________________________________________________

_____________________________________________________________

_____________________________________________________________
```

---

## 🎉 Déploiement

Si tous les tests sont passés:

1. [ ] Générer l'APK de production: `flutter build apk --release`
2. [ ] Signer l'APK si nécessaire
3. [ ] Déployer sur le magasin d'applications
4. [ ] Notifier les utilisateurs
5. [ ] Collecter les retours utilisateurs

**L'application est prête pour production! 🚀**