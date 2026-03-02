#!/usr/bin/env python3
"""Script pour configurer et tester le mot de passe PostgreSQL"""
import os
import sys
import getpass

def update_env_password():
    """Mettre à jour le mot de passe dans .env"""
    print("=" * 60)
    print("🔐 CONFIGURATION DU MOT DE PASSE POSTGRESQL")
    print("=" * 60)
    print()
    print("Entrez votre mot de passe PostgreSQL")
    print("(celui que vous utilisez pour vous connecter à PostgreSQL)")
    print()
    
    password = getpass.getpass("Mot de passe PostgreSQL: ")
    
    if not password:
        print("❌ Mot de passe vide!")
        return False
    
    # Lire le fichier .env
    env_path = ".env"
    if not os.path.exists(env_path):
        print(f"❌ Fichier {env_path} introuvable!")
        return False
    
    with open(env_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Mettre à jour la ligne DB_PASSWORD
    updated = False
    for i, line in enumerate(lines):
        if line.startswith('DB_PASSWORD='):
            lines[i] = f'DB_PASSWORD={password}\n'
            updated = True
            break
    
    if not updated:
        lines.append(f'DB_PASSWORD={password}\n')
    
    # Écrire le fichier
    with open(env_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    print("✅ Mot de passe mis à jour dans .env")
    return True

def test_connection():
    """Tester la connexion PostgreSQL"""
    print("\n🧪 Test de connexion...")
    
    try:
        import psycopg2
        from dotenv import load_dotenv
        
        # Recharger les variables d'environnement
        load_dotenv(override=True)
        
        db_config = {
            "host": os.getenv("DB_HOST", "localhost"),
            "database": "postgres",
            "user": os.getenv("DB_USER", "postgres"),
            "password": os.getenv("DB_PASSWORD"),
            "port": os.getenv("DB_PORT", "5432")
        }
        
        conn = psycopg2.connect(**db_config)
        conn.close()
        
        print("✅ Connexion PostgreSQL réussie!")
        return True
        
    except psycopg2.OperationalError as e:
        print(f"❌ Erreur de connexion: {e}")
        print("\n💡 Vérifiez que:")
        print("   1. PostgreSQL est démarré (services.msc)")
        print("   2. Le mot de passe est correct")
        return False
    except ImportError:
        print("❌ Module psycopg2 non installé")
        print("   Installez avec: pip install psycopg2")
        return False

if __name__ == "__main__":
    if update_env_password():
        if test_connection():
            print("\n" + "=" * 60)
            print("✅ CONFIGURATION TERMINÉE")
            print("=" * 60)
            print("\nProchaines étapes:")
            print("1. python setup_db.py          (Créer la base de données)")
            print("2. python create_test_user.py  (Créer utilisateur test)")
            print("3. python -m uvicorn main:app --reload --port 8000")
            print("4. python test_login.py        (Tester le login)")
        else:
            print("\n❌ La connexion a échoué. Réessayez avec le bon mot de passe.")
    
    print()
    input("Appuyez sur Entrée pour continuer...")
