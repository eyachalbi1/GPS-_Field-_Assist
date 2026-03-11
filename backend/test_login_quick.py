import requests

# Test local
url_local = "http://localhost:8000/api/auth/login"
# Test cloud
url_cloud = "https://gps-field-assist.onrender.com/api/auth/login"

data = {"username": "tech1", "password": "password123"}
headers = {"Content-Type": "application/json", "Accept": "application/json"}

try:
    response = requests.post(url_local, json=data, headers=headers)
    print(f"Local - Status: {response.status_code}")
    if response.status_code == 200:
        print(f"Local - Token reçu")
    else:
        print(f"Local - Error: {response.text}")
except:
    print("Local - Serveur non accessible")

try:
    response = requests.post(url_cloud, json=data, headers=headers, timeout=10)
    print(f"Cloud - Status: {response.status_code}")
    if response.status_code == 200:
        print(f"Cloud - Token reçu")
    elif response.status_code == 422:
        print(f"Cloud - Erreur validation: {response.text}")
    else:
        print(f"Cloud - Error: {response.text}")
except Exception as e:
    print(f"Cloud - Erreur: {e}")
