from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from src.models.database import get_db, verify_password
from src.services.auth_service import verify_token

security = HTTPBearer()

def authenticate_user(username: str, password: str):
    try:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
                user = cursor.fetchone()
                
                if user and verify_password(password, user["password"]):
                    return {
                        "id": user["id"],
                        "username": user["username"],
                        "role": user["role"]
                    }
        return None
    except Exception:
        return None

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    payload = verify_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Token invalide")
    return payload

