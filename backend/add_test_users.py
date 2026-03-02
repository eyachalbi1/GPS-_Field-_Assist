#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour ajouter des utilisateurs de test dans la base de données
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.models.database import add_test_users, get_all_users

def main():
    try:
        print("Ajout des utilisateurs de test...")
        add_test_users()

        print("✅ Utilisateurs de test ajoutés avec succès !")
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
            username = user['username']
            role = user['role']
            date_creation = user['date_de_creation'].strftime('%Y-%m-%d %H:%M:%S') if user['date_de_creation'] else 'N/A'

            print(f"{user_id:<5} {username:<20} {role:<15} {date_creation:<20}")

        print("-" * 80)
        print()
        print("🔑 Identifiants de test ajoutés :")
        print("• technicien1 / tech123 (technicien)")
        print("• technicien2 / tech123 (technicien)")
        print("• admin2 / admin123 (admin)")
        print("• superviseur / super123 (admin)")

    except Exception as e:
        print(f"❌ Erreur lors de l'ajout des utilisateurs de test: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()