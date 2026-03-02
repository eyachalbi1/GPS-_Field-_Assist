import requests
import json

url = "http://localhost:8000/api/auth/login"
data = {"username": "tech1", "password": "password123"}

try:
    response = requests.post(url, json=data)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")
