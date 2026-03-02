import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": "postgres",
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"),
    "port": os.getenv("DB_PORT", "5432")
}

DB_NAME = os.getenv("DB_NAME", "tunav_gps_tracking_db")

print("Configuration de la base de donnees...")

try:
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = True
    cursor = conn.cursor()
    
    cursor.execute(f"SELECT 1 FROM pg_database WHERE datname='{DB_NAME}'")
    if not cursor.fetchone():
        cursor.execute(f"CREATE DATABASE {DB_NAME}")
        print(f"Base de donnees '{DB_NAME}' creee")
    else:
        print(f"Base de donnees '{DB_NAME}' existe deja")
    
    cursor.close()
    conn.close()
    
    from src.models.database import init_users_table
    init_users_table()
    print("Tables initialisees avec succes")
    
except Exception as e:
    print(f"Erreur: {e}")
    exit(1)
