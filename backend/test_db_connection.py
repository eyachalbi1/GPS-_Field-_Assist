#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de test de connexion à la base de données
"""

import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": os.getenv("DB_NAME", "tunav_gps_tracking_db"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "password"),
    "port": os.getenv("DB_PORT", "5432"),
    "client_encoding": "utf8"
}

def test_connection():
    try:
        print("🔍 Test de connexion à la base de données...")

        # Test de connexion basique
        conn = psycopg2.connect(**DB_CONFIG)
        conn.close()

        print("✅ Connexion basique réussie !")

        # Test avec requête simple
        conn = psycopg2.connect(**DB_CONFIG)
        with conn.cursor() as cursor:
            # Récupérer le nom de la base de données
            cursor.execute("SELECT current_database()")
            db_name = cursor.fetchone()[0]

            print(f"📊 Base de données : {db_name}")

            # Test simple : compter les utilisateurs
            cursor.execute("SELECT COUNT(*) FROM users")
            count = cursor.fetchone()[0]

            print(f"👥 Nombre d'utilisateurs : {count}")

        conn.close()
        return True

    except Exception as e:
        print(f"❌ Erreur de connexion : {e}")
        return False

if __name__ == "__main__":
    test_connection()