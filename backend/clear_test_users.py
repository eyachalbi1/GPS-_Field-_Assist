#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour supprimer les utilisateurs de test de la base de données
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.models.database import get_db

def clear_test_users():
    """Supprimer tous les utilisateurs de test (garde seulement admin)"""
    test_usernames = ['technicien1', 'technicien2', 'admin2', 'superviseur']

    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                DELETE FROM users
                WHERE username = ANY(%s)
            """, (test_usernames,))
            deleted_count = cursor.rowcount
            conn.commit()
            return deleted_count

def main():
    try:
        print("Suppression des utilisateurs de test...")
        deleted_count = clear_test_users()

        print(f"✅ {deleted_count} utilisateurs de test supprimés avec succès !")
        print()
        print("Seul l'utilisateur 'admin' original est conservé.")

    except Exception as e:
        print(f"❌ Erreur lors de la suppression des utilisateurs de test: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()