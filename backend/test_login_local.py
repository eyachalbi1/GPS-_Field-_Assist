import requests
import json

# Test login API
url = "http://localhost:8000/api/auth/login"
data = {"username": "admin", "password": "admin123"}
headers = {"Content-Type": "application/json"}

try:
    response = requests.post(url, json=data, headers=headers)
    result = f"Status: {response.status_code}\nResponse: {response.text}"
except Exception as e:
    result = f"Error: {e}"

# Write to file
with open("login_test_result.txt", "w", encoding="utf-8") as f:
    f.write(result)
print(result)

