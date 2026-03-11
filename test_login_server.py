import requests
import json

url = "http://192.168.2.115:8000/api/auth/login"
data = {"username": "admin", "password": "admin123"}

try:
    response = requests.post(url, json=data)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")

