#!/usr/bin/env python3
import requests
import json

BASE_URL = "http://localhost:8000/api/auth"

def test_login():
    login_data = {
        "username": input("Username: "),
        "password": input("Password: ")
    }
    
    try:
        response = requests.post(f"{BASE_URL}/login", json=login_data)
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Login réussi!")
            print(f"Token: {result['token'][:50]}...")
            print(f"User: {result['user']}")
        else:
            print(f"❌ Login échoué: {response.json()}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Serveur non accessible. Lancez d'abord: python -m uvicorn main:app --reload --port 8000")
    except Exception as e:
        print(f"❌ Erreur: {e}")

if __name__ == "__main__":
    test_login()