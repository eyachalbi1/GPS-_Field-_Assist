#!/usr/bin/env python3
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from src.models.database import get_db, hash_password

def add_technician():
    username = input("Nom d'utilisateur: ")
    email = input("Email: ")
    password = input("Mot de passe: ")
    
    try:
        with get_db() as conn:
            with conn.cursor() as cursor:
                hashed_pwd = hash_password(password)
                cursor.execute("""
                    INSERT INTO users (username, email, password, role)
                    VALUES (%s, %s, %s, 'technicien')
                    RETURNING id
                """, (username, email, hashed_pwd))
                conn.commit()
                user_id = cursor.fetchone()['id']
                print(f"✅ Technicien '{username}' ajouté avec succès (ID: {user_id})")
    except Exception as e:
        print(f"❌ Erreur: {str(e)}")

def delete_technician():
    username = input("Nom d'utilisateur à supprimer: ")
    
    try:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    DELETE FROM users WHERE username = %s AND role = 'technicien'
                """, (username,))
                conn.commit()
                if cursor.rowcount > 0:
                    print(f"✅ Technicien '{username}' supprimé avec succès")
                else:
                    print(f"❌ Technicien '{username}' non trouvé")
    except Exception as e:
        print(f"❌ Erreur: {str(e)}")

def list_technicians():
    try:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT id, username, email, created_at 
                    FROM users WHERE role = 'technicien'
                    ORDER BY created_at DESC
                """)
                technicians = cursor.fetchall()
                
                if not technicians:
                    print("Aucun technicien trouvé")
                    return
                
                print("\n📋 Liste des techniciens:")
                print("-" * 60)
                for tech in technicians:
                    print(f"ID: {tech['id']} | {tech['username']} | {tech['email']} | {tech['created_at']}")
    except Exception as e:
        print(f"❌ Erreur: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python admin_postgres.py [add|delete|list]")
    elif sys.argv[1] == "add":
        add_technician()
    elif sys.argv[1] == "delete":
        delete_technician()
    elif sys.argv[1] == "list":
        list_technicians()
    else:
        print("Commande inconnue. Utilisez: add, delete, ou list")