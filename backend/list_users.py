#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour lister tous les utilisateurs de la base de données
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.models.database import get_all_users

def main():
    try:
        users = get_all_users()

        if not users:
            print("Aucun utilisateur trouvé dans la base de données.")
            return

        print("=== LISTE DES UTILISATEURS ===")
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

    except Exception as e:
        print(f"Erreur lors de la récupération des utilisateurs: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()