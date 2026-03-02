# 📘 Guide d'Utilisation - Application Mobile GPS Field Assist

## 🎯 Vue d'Ensemble

L'application mobile GPS Field Assist est une application de gestion des modules GPS avec les fonctionnalités suivantes :

- **Authentification** - Connexion sécurisée
- **Gestion des Tâches (TODO)** - Organisation des travaux
- **Assets GPS** - Catalogue des modules GPS
- **Diagnostic** - Configuration et test des modules
- **Téléchargement de PDFs** - Accès aux manuels

---

## 🔐 Authentification

### Identifiants de Test

```
Nom d'utilisateur: tech1
Mot de passe: password123
```

### Processus de Connexion

1. Lancez l'application
2. Entrez vos identifiants
3. Cliquez sur "Se connecter"
4. Vous êtes dirigé vers l'écran d'accueil

---

## 🏠 Écran d'Accueil (Home Screen)

### Barre Latérale Gauche

- **TO DO** (Blanc) - Liste des tâches à effectuer
- **ASSETS** (Bleu) - Catalogue des modules GPS
- **DIAGNOSTIQUE** (Vert) - Configuration et test

### Navigation

Cliquez sur les icônes de la barre latérale pour naviguer entre les sections.

---

## 📋 Section TO DO

### Affichage des Tâches

Les tâches sont classées par statut avec des couleurs différentes :

- 🔴 **TODO** (Rouge clair) - En attente
- 🟡 **In Progress** (Jaune) - En cours
- 🟢 **Completed** (Vert clair) - Terminées

### Actions sur les Tâches

1. Cliquez sur une tâche pour voir les détails
2. Vous pouvez ajouter des photos/fichiers
3. Changer le statut de la tâche
4. Voir les fichiers associés

---

## 📱 Section ASSETS (Modules GPS)

### Affichage du Catalogue

- **Grille adaptative** - Montre les modules sous forme de cartes
- **Chaque module affiche**
  - Photo du module
  - Nom du module
  - IMEI du module

### Recherche

- Utilisez la barre de recherche en haut
- Recherchez par nom ou IMEI
- Les résultats se filtrent en temps réel

### Détails du Module

Cliquez sur une carte pour voir :

- 📷 Photo du module
- 📝 Description
- 🏷️ IMEI
- ✅ Caractéristiques principales
- 📖 Bouton "Manuel d'utilisation (PDF)"

### PDFs Disponibles

Depuis les détails du module, cliquez sur le bouton PDF pour consulter le manuel :
- Le PDF s'ouvre dans l'application
- Vous pouvez faire défiler et zoomer
- Bouton fermer pour revenir

---

## 🔧 Section DIAGNOSTIQUE - Configuration

### Accès

1. Cliquez sur "DIAGNOSTIQUE" dans la barre latérale
2. Vous verrez une liste de modules
3. Cliquez sur "Ouvrir" pour la section "Configuration"

### Sections Disponibles

Trois onglets à sélectionner :
- **Firmware** - Mise à jour du firmware
- **Configuration** - Paramètres du module
- **Diagnostique** - Tests du module

### Écran de Configuration

#### Champs à Remplir

**Numéro IMEI** 
- Numéro IMEI du téléphone
- Format: 15 chiffres
- Exemple: 352099087484613

**Description du Module**
- Description libre du module
- Utile pour les notes techniques

**Numéro de Téléphone**
- Numéro pour la communication SMS
- Format international: +216 22 000 000
- Utilisé pour tester la connexion SMS

#### Boutons d'Action

**Envoyer SMS** 🔵
- Envoie un SMS au numéro saisi
- Ouvre l'application SMS du téléphone
- Permet de tester la communication

**Consulter le Manuel (PDF)** 📄
- Affiche le manuel du module
- Accessible directement dans l'application
- PDFs disponibles

---

## 📥 Téléchargement de PDFs

### Accès à l'Écran de Téléchargement

1. Depuis la section Diagnostique
2. Cliquez sur l'icône PDF rouge 🔴📄 dans la barre d'outils
3. L'écran de téléchargement s'ouvre

### PDFs Disponibles

- GPS Tracker Manual (2016)
- EasyCan Instructions
- EasyCan Digital Manual
- Module 5227793

### Actions pour Chaque PDF

**Voir** 👁️
- Consulte le PDF dans l'application
- Navigation rapide
- Zoom support

**Télécharger** ⬇️
- Télécharge le PDF sur votre appareil
- Stocké dans le dossier Downloads
- Vous pouvez l'ouvrir hors de l'application

### Emplacement des Fichiers

- **Android** : `Downloads/{nom_pdf}.pdf`
- **iOS** : Fichiers de l'application

---

## 🛠️ Boutons d'Outils

### En Haut à Droite

**Paramètres** ⚙️
- Options de thème (clair/sombre)
- Paramètres utilisateur

### Dans la Barre Diagnostique

**Recherche** 🔍
- Recherchez un module

**Scanner QR** 📱
- Scan de codes QR des modules

**Téléchargement PDF** 📄
- Accès rapide aux PDFs

---

## ⚙️ Configuration Réseau

### Connexion au Serveur

L'application est configurée pour se connecter à :

```
Serveur: http://192.168.0.2:8000
```

### Prérequis

- Le téléphone doit être connecté au **même réseau Wi-Fi** que le serveur
- Le serveur backend doit être démarré
- La connexion Internet est requise

### Si la Connexion Échoue

1. Vérifiez que le serveur est démarré
2. Vérifiez que vous êtes sur le même réseau
3. Vérifiez l'IP de l'ordinateur
4. Modifiez `mobile/lib/utils/config.dart` si nécessaire

---

## 🎨 Thème

### Mode Clair (Défaut)
- Fond avec image Tunav
- Interface blanche
- Idéal pour l'extérieur

### Mode Sombre
- Fond noir
- Interface sombre
- Économise la batterie

**Comment changer** :
- Cliquez sur l'icône de paramètres en haut à droite
- Sélectionnez le mode

---

## ✅ Checklist d'Utilisation

Avant de commencer :

- [ ] L'application est installée
- [ ] Vous êtes connecté au Wi-Fi
- [ ] Le serveur backend est démarré
- [ ] Vous avez les identifiants (tech1 / password123)

Pendant l'utilisation :

- [ ] Vous pouvez voir les modules dans Assets
- [ ] Les photos s'affichent correctement
- [ ] Vous pouvez ouvrir les PDFs
- [ ] Vous pouvez envoyer des SMS
- [ ] Les tâches se sauvegardent

---

## 🆘 Dépannage

### Les photos ne s'affichent pas

- Vérifiez que les fichiers images sont dans `assets/modules_gps/`
- Redémarrez l'application
- Vérifiez la connexion réseau

### Les PDFs ne s'ouvrent pas

- Vérifiez que les fichiers PDF sont dans `pdfs_modules/`
- Essayez de télécharger le PDF
- Vérifiez la capacité de stockage

### La connexion échoue

- Vérifiez que le serveur est démarré
- Vérifiez que vous êtes sur le même réseau
- Vérifiez l'IP dans `config.dart`

### Le SMS ne s'envoie pas

- Vérifiez que vous avez entré un numéro valide
- Vérifiez que l'application SMS est disponible
- Vérifiez les permissions de l'application

---

## 📞 Support

Pour toute aide supplémentaire, veuillez contacter :
- L'administrateur système
- L'équipe de support technique

---

## 🔄 Mises à Jour

L'application reçoit régulièrement des mises à jour :

- Nouvelles fonctionnalités
- Corrections de bugs
- Améliorations de performance

Veuillez vérifier régulièrement les mises à jour.