#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour ajouter un utilisateur spécifique via ligne de commande
Usage: py add_user_cmd.py <username> <password> <role>
Exemple: py add_user_cmd.py john secret123 admin
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.models.database import add_user, get_all_users

def main():
    if len(sys.argv) != 4:
        print("Usage: py add_user_cmd.py <username> <password> <role>")
        print("Exemple: py add_user_cmd.py john secret123 admin")
        print("Rôles disponibles: admin, technicien")
        sys.exit(1)

    username = sys.argv[1]
    password = sys.argv[2]
    role = sys.argv[3]

    try:
        print(f"Ajout de l'utilisateur '{username}' avec le rôle '{role}'...")
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

    except ValueError as e:
        print(f"❌ Erreur de validation: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Erreur lors de l'ajout de l'utilisateur: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()