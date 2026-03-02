#!/usr/bin/env python3
import requests
import json

BASE_URL = "http://localhost:8000/api/auth"

def test_login_success():
    """Test login avec des identifiants valides"""
    print("\n🧪 Test 1: Login avec identifiants valides")
    login_data = {
        "username": "tech1",
        "password": "password123"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/login", json=login_data)
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Login réussi!")
            print(f"   Token: {result['token'][:50]}...")
            print(f"   User: {result['user']}")
            return result['token']
        else:
            print(f"❌ Échec: {response.status_code} - {response.json()}")
            return None
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return None

def test_login_invalid_password():
    """Test login avec mot de passe incorrect"""
    print("\n🧪 Test 2: Login avec mot de passe incorrect")
    login_data = {
        "username": "tech1",
        "password": "wrongpassword"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/login", json=login_data)
        
        if response.status_code == 401:
            print("✅ Rejet correct des identifiants invalides")
            print(f"   Message: {response.json()}")
        else:
            print(f"❌ Comportement inattendu: {response.status_code}")
    except Exception as e:
        print(f"❌ Erreur: {e}")

def test_login_invalid_username():
    """Test login avec utilisateur inexistant"""
    print("\n🧪 Test 3: Login avec utilisateur inexistant")
    login_data = {
        "username": "usernotexist",
        "password": "password123"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/login", json=login_data)
        
        if response.status_code == 401:
            print("✅ Rejet correct de l'utilisateur inexistant")
            print(f"   Message: {response.json()}")
        else:
            print(f"❌ Comportement inattendu: {response.status_code}")
    except Exception as e:
        print(f"❌ Erreur: {e}")

def test_login_empty_fields():
    """Test login avec champs vides"""
    print("\n🧪 Test 4: Login avec champs vides")
    login_data = {
        "username": "",
        "password": ""
    }
    
    try:
        response = requests.post(f"{BASE_URL}/login", json=login_data)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.json()}")
    except Exception as e:
        print(f"❌ Erreur: {e}")

def run_all_tests():
    """Exécuter tous les tests"""
    print("=" * 60)
    print("🚀 TESTS DE LOGIN BACKEND - GPS Field Assist")
    print("=" * 60)
    
    try:
        # Vérifier que le serveur est accessible
        response = requests.get("http://localhost:8000")
        print("✅ Serveur accessible\n")
    except requests.exceptions.ConnectionError:
        print("❌ Serveur non accessible!")
        print("   Lancez d'abord: python -m uvicorn main:app --reload --port 8000")
        return
    
    # Exécuter les tests
    test_login_success()
    test_login_invalid_password()
    test_login_invalid_username()
    test_login_empty_fields()
    
    print("\n" + "=" * 60)
    print("✅ Tests terminés")
    print("=" * 60)

if __name__ == "__main__":
    run_all_tests()
