"""
Script de diagnostic complet pour le serveur GPS Field Assist
Teste la connexion, la base de données et l'API
"""
import requests
import json
import socket
import sys

def get_local_ip():
    """Obtenir l'adresse IP locale du PC"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "127.0.0.1"

def test_server():
    local_ip = get_local_ip()
    print("=" * 50)
    print("   DIAGNOSTIC SERVEUR GPS FIELD ASSIST")
    print("=" * 50)
    print()
    print(f"[INFO] IP locale du PC: {local_ip}")
    print(f"[INFO] Utilisez cette IP dans l'application mobile!")
    print()
    
    # Test 1: Serveur local
    print("[TEST 1] Connexion au serveur local...")
    try:
        response = requests.get("http://localhost:8000/", timeout=5)
        print(f"  ✓ Serveur accessible: Status {response.status_code}")
        print(f"  Réponse: {response.json()}")
    except requests.exceptions.ConnectionError:
        print("  ✗ Serveur NON accessible sur localhost:8000")
        print("  >> Démarrez le serveur avec: start_server.bat")
        return False
    except Exception as e:
        print(f"  ✗ Erreur: {e}")
        return False
    
    print()
    
    # Test 2: Test de l'API login
    print("[TEST 2] Test de l'API /api/auth/login...")
    test_users = [
        ("admin", "admin123"),
        ("tech1", "tech123"),
        ("technicien1", "tech123"),
    ]
    
    for username, password in test_users:
        try:
            response = requests.post(
                "http://localhost:8000/api/auth/login",
                json={"username": username, "password": password},
                timeout=5
            )
            if response.status_code == 200:
                data = response.json()
                print(f"  ✓ Connexion réussie avec: {username}")
                print(f"    Token: {data.get('token', 'N/A')[:20]}...")
                print(f"    User: {data.get('user', {})}")
                break
            elif response.status_code == 401:
                print(f"  ✗ Identifiants incorrects: {username}")
            else:
                print(f"  ? Status {response.status_code}: {response.text}")
        except Exception as e:
            print(f"  ✗ Erreur pour {username}: {e}")
    
    print()
    
    # Test 3: Test de l'endpoint /health
    print("[TEST 3] Test de l'endpoint /health...")
    try:
        response = requests.get("http://localhost:8000/health", timeout=5)
        print(f"  ✓ Health check: {response.json()}")
    except Exception as e:
        print(f"  ✗ Erreur: {e}")
    
    print()
    
    # Test 4: Liste des utilisateurs
    print("[TEST 4] Liste des utilisateurs...")
    try:
        response = requests.get("http://localhost:8000/api/auth/users", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"  ✓ Utilisateurs trouvés: {data.get('total', 0)}")
            for user in data.get('users', [])[:5]:
                print(f"    - {user.get('username')} ({user.get('role')})")
        else:
            print(f"  ? Status: {response.status_code}")
    except Exception as e:
        print(f"  ✗ Erreur: {e}")
    
    print()
    print("=" * 50)
    print("   INSTRUCTIONS POUR LE MOBILE")
    print("=" * 50)
    print(f"1. IP du PC: {local_ip}")
    print("2. Démarrez le serveur: backend\\start_server.bat")
    print("3. Configurez le pare-feu: configure_firewall.bat")
    print("4. Dans l'app mobile:")
    print("   - Allez dans Diagnostique")
    print("   - Configuration Serveur")
    print(f"   - Entrez l'IP: {local_ip}")
    print("   - Sauvegardez")
    print("5. Revenez à l'écran de login et reconnectez-vous")
    print("=" * 50)
    
    return True

if __name__ == "__main__":
    test_server()
    print()
    input("Appuyez sur Entrée pour quitter...")

