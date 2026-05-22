import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from src.services.auth_service import create_access_token, verify_token
from src.models.database import verify_password, hash_password


def test_create_and_verify_token():
    payload = {"sub": "admin", "role": "admin", "user_id": 1}
    token = create_access_token(payload)
    assert token is not None
    decoded = verify_token(token)
    assert decoded["sub"] == "admin"
    assert decoded["role"] == "admin"
    assert decoded["user_id"] == 1


def test_verify_token_invalid():
    assert verify_token("token_invalide_xyz") is None


def test_verify_token_tampered():
    token = create_access_token({"sub": "admin", "role": "admin", "user_id": 1})
    assert verify_token(token[:-5] + "XXXXX") is None


def test_hash_and_verify_password():
    hashed = hash_password("admin123")
    assert hashed != "admin123"
    assert verify_password("admin123", hashed) is True


def test_wrong_password():
    hashed = hash_password("admin123")
    assert verify_password("mauvais_mdp", hashed) is False


def test_import_routes():
    from src.routes import auth, ai, tasks, gps
    assert auth.router is not None
    assert ai.router is not None
    assert tasks.router is not None
    assert gps.router is not None


def test_import_main():
    import main
    assert main.app is not None
