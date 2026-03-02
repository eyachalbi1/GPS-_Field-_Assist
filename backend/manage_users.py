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
    "port": os.getenv("DB_PORT", "5432")
}

def get_connection():
    return psycopg2.connect(**DB_CONFIG)

def list_users():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, username, role, date_de_creation FROM users ORDER BY id")
    users = cursor.fetchall()
    
    print("\n" + "="*80)
    print("LISTE DES UTILISATEURS")
    print("="*80)
    print(f"{'ID':<5} {'Username':<20} {'Role':<15} {'Date de creation'}")
    print("-"*80)
    
    for user in users:
        print(f"{user[0]:<5} {user[1]:<20} {user[2]:<15} {user[3]}")
    
    print("="*80)
    print(f"Total: {len(users)} utilisateur(s)\n")
    
    cursor.close()
    conn.close()

def add_user():
    print("\n--- AJOUTER UN UTILISATEUR ---")
    username = input("Username: ")
    password = input("Password: ")
    role = input("Role (technicien/admin): ")
    
    if role not in ['technicien', 'admin']:
        print("Role invalide!")
        return
    
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        hashed_password = pwd_context.hash(password)
        cursor.execute("""
            INSERT INTO users (username, password, role)
            VALUES (%s, %s, %s)
        """, (username, hashed_password, role))
        conn.commit()
        print(f"\nUtilisateur '{username}' cree avec succes!")
    except Exception as e:
        print(f"\nErreur: {e}")
    
    cursor.close()
    conn.close()

def delete_user():
    list_users()
    user_id = input("ID de l'utilisateur a supprimer (0 pour annuler): ")
    
    if user_id == "0":
        return
    
    confirm = input(f"Confirmer la suppression de l'utilisateur ID {user_id}? (oui/non): ")
    if confirm.lower() != "oui":
        print("Annule")
        return
    
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
        conn.commit()
        if cursor.rowcount > 0:
            print(f"\nUtilisateur ID {user_id} supprime!")
        else:
            print(f"\nUtilisateur ID {user_id} introuvable")
    except Exception as e:
        print(f"\nErreur: {e}")
    
    cursor.close()
    conn.close()

def main():
    while True:
        print("\n" + "="*50)
        print("GESTION DES UTILISATEURS - GPS FIELD ASSIST")
        print("="*50)
        print("1. Visualiser tous les utilisateurs")
        print("2. Ajouter un utilisateur")
        print("3. Supprimer un utilisateur")
        print("4. Quitter")
        print("="*50)
        
        choice = input("\nVotre choix: ")
        
        if choice == "1":
            list_users()
        elif choice == "2":
            add_user()
        elif choice == "3":
            delete_user()
        elif choice == "4":
            print("\nAu revoir!")
            break
        else:
            print("\nChoix invalide!")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nInterrompu par l'utilisateur")
    except Exception as e:
        print(f"\nErreur: {e}")
