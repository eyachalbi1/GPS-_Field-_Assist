import pytest
from fastapi.testclient import TestClient
import sys, os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

try:
    from main import app
    client = TestClient(app)
    APP_AVAILABLE = True
except Exception:
    APP_AVAILABLE = False


@pytest.mark.skipif(not APP_AVAILABLE, reason="App non disponible sans DB")
def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.skipif(not APP_AVAILABLE, reason="App non disponible sans DB")
def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


@pytest.mark.skipif(not APP_AVAILABLE, reason="App non disponible sans DB")
def test_login_missing_fields():
    response = client.post("/api/auth/login", json={})
    assert response.status_code in [400, 422]


@pytest.mark.skipif(not APP_AVAILABLE, reason="App non disponible sans DB")
def test_login_wrong_credentials():
    response = client.post("/api/auth/login", json={
        "username": "fakeuser",
        "password": "fakepass"
    })
    assert response.status_code in [401, 403, 404]
