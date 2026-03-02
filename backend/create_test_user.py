import psycopg2
from passlib.context import CryptContext
import os
from dotenv import load_dotenv

load_dotenv()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": os.getenv("DB_NAME", "tunav_gps_tracking_db"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"),
    "port": os.getenv("DB_PORT", "5432"),
    "client_encoding": "utf8"
}

print("Creation de l'utilisateur technicien...")

try:
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()
    
    hashed_password = pwd_context.hash("password123")
    
    cursor.execute("""
        INSERT INTO users (username, password, role)
        VALUES (%s, %s, %s)
        ON CONFLICT (username) DO UPDATE 
        SET password = EXCLUDED.password
    """, ("tech1", hashed_password, "technicien"))
    
    conn.commit()
    
    print("Utilisateur cree: tech1 / password123")
    
    cursor.close()
    conn.close()
    
except Exception as e:
    print(f"Erreur: {e}")
    exit(1)
