import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from src.models.database import get_db_connection
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def create_technician():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Données du technicien
    username = "technicien1"
    password = "tech2024"
    
    # Hash du mot de passe
    hashed_password = pwd_context.hash(password)
    
    # Vérifier si l'utilisateur existe déjà
    cursor.execute("SELECT username FROM users WHERE username = %s", (username,))
    if cursor.fetchone():
        print(f"✓ L'utilisateur '{username}' existe déjà")
    else:
        # Créer l'utilisateur
        cursor.execute(
            "INSERT INTO users (username, password) VALUES (%s, %s)",
            (username, hashed_password)
        )
        conn.commit()
        print(f"✓ Technicien créé avec succès!")
    
    cursor.close()
    conn.close()
    
    print("\n" + "="*60)
    print("IDENTIFIANTS DU TECHNICIEN")
    print("="*60)
    print(f"Username : {username}")
    print(f"Password : {password}")
    print("="*60)

if __name__ == "__main__":
    try:
        create_technician()
    except Exception as e:
        print(f"Erreur: {e}")
        sys.exit(1)
