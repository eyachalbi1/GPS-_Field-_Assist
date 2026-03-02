#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour ajouter un utilisateur personnalisé dans la base de données
"""

import sys
import os
import getpass
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.models.database import add_user, get_all_users

def main():
    try:
        print("=== AJOUT D'UN UTILISATEUR PERSONNALISÉ ===")
        print()

        # Saisie du nom d'utilisateur
        while True:
            username = input("Nom d'utilisateur (max 20 caractères) : ").strip()
            if not username:
                print("❌ Le nom d'utilisateur ne peut pas être vide.")
                continue
            if len(username) > 20:
                print("❌ Le nom d'utilisateur ne peut pas dépasser 20 caractères.")
                continue
            break

        # Saisie du mot de passe
        while True:
            password = getpass.getpass("Mot de passe : ")
            if not password:
                print("❌ Le mot de passe ne peut pas être vide.")
                continue
            confirm_password = getpass.getpass("Confirmer le mot de passe : ")
            if password != confirm_password:
                print("❌ Les mots de passe ne correspondent pas.")
                continue
            break

        # Saisie du rôle
        while True:
            print("\nRôles disponibles :")
            print("1. admin     - Accès complet")
            print("2. technicien - Accès limité")
            role_choice = input("Choisissez le rôle (1 ou 2) : ").strip()

            if role_choice == "1":
                role = "admin"
                break
            elif role_choice == "2":
                role = "technicien"
                break
            else:
                print("❌ Choix invalide. Veuillez saisir 1 ou 2.")

        # Confirmation
        print(f"\n📋 Récapitulatif :")
        print(f"   Utilisateur : {username}")
        print(f"   Rôle : {role}")
        confirm = input("\nConfirmer l'ajout de cet utilisateur ? (o/n) : ").strip().lower()

        if confirm not in ['o', 'oui', 'y', 'yes']:
            print("❌ Ajout annulé.")
            return

        # Ajout de l'utilisateur
        print("\nAjout de l'utilisateur...")
        success = add_user(username, password, role)

        if success:
            print("✅ Utilisateur ajouté avec succès !")
        else:
            print("⚠️ L'utilisateur existe déjà et a été mis à jour.")

        print()

        # Afficher la liste mise à jour
        users = get_all_users()
        print("=== LISTE MISE À JOUR DES UTILISATEURS ===")
        print(f"Nombre total d'utilisateurs: {len(users)}")
        print("-" * 80)
        print(f"{'ID':<5} {'Username':<20} {'Role':<15} {'Date de création':<20}")
        print("-" * 80)

        for user in users:
            user_id = user['id']
            user_username = user['username']
            user_role = user['role']
            date_creation = user['date_de_creation'].strftime('%Y-%m-%d %H:%M:%S') if user['date_de_creation'] else 'N/A'

            print(f"{user_id:<5} {user_username:<20} {user_role:<15} {date_creation:<20}")

        print("-" * 80)

    except KeyboardInterrupt:
        print("\n\n❌ Ajout annulé par l'utilisateur.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Erreur lors de l'ajout de l'utilisateur: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()