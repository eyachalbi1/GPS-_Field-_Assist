s#!/usr/bin/env python
import requests
import json

print("Testing server...")

# Test 1: Root endpoint
try:
    r = requests.get("http://localhost:8000/", timeout=5)
    print(f"GET / : {r.status_code} - {r.text}")
except Exception as e:
    print(f"GET / : ERROR - {e}")

# Test 2: Login endpoint
try:
    data = {"username": "admin", "password": "admin123"}
    r = requests.post("http://localhost:8000/api/auth/login", json=data, timeout=5)
    print(f"POST /api/auth/login : {r.status_code}")
    if r.status_code == 200:
        print(f"  Response: {r.json()}")
    else:
        print(f"  Error: {r.text}")
except Exception as e:
    print(f"POST /api/auth/login : ERROR - {e}")

# Test 3: Get users
try:
    r = requests.get("http://localhost:8000/api/auth/users", timeout=5)
    print(f"GET /api/auth/users : {r.status_code}")
    if r.status_code == 200:
        print(f"  Response: {r.json()}")
except Exception as e:
    print(f"GET /api/auth/users : ERROR - {e}")

