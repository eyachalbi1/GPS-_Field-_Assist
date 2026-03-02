#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour créer une nouvelle base de données de test
"""

import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

# Configuration pour se connecter à postgres (base système)
DB_CONFIG_POSTGRES = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": "postgres",  # Base système PostgreSQL
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "password"),
    "port": os.getenv("DB_PORT", "5432")
}

# Configuration pour la nouvelle base de données
TARGET_DB = "tunav_gps_tracking_db"

def create_database():
    try:
        print(f"🔍 Création de la base de données '{TARGET_DB}'...")

        # Se connecter à la base postgres système
        conn = psycopg2.connect(**DB_CONFIG_POSTGRES)
        conn.autocommit = True

        with conn.cursor() as cursor:
            # Vérifier si la base existe déjà
            cursor.execute("SELECT datname FROM pg_database WHERE datname = %s", (TARGET_DB,))
            exists = cursor.fetchone()

            if exists:
                print(f"⚠️ La base de données '{TARGET_DB}' existe déjà.")
            else:
                # Créer la base de données
                cursor.execute(f"CREATE DATABASE {TARGET_DB} ENCODING 'UTF8'")
                print(f"✅ Base de données '{TARGET_DB}' créée avec succès !")

        conn.close()

        # Tester la connexion à la nouvelle base
        test_config = DB_CONFIG_POSTGRES.copy()
        test_config["database"] = TARGET_DB

        conn = psycopg2.connect(**test_config)
        with conn.cursor() as cursor:
            cursor.execute("SELECT current_database()")
            db_name = cursor.fetchone()[0]
            print(f"📊 Connexion confirmée à : {db_name}")

        conn.close()
        return True

    except Exception as e:
        print(f"❌ Erreur lors de la création de la base : {e}")
        return False

if __name__ == "__main__":
    create_database()