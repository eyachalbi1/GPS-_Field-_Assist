from fastapi import APIRouter, HTTPException
from src.models.schemas import LoginRequest, LoginResponse
from src.controllers.auth_controller import authenticate_user
from src.services.auth_service import create_access_token
from src.models.database import get_all_users

router = APIRouter()

@router.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    user = authenticate_user(request.username, request.password)
    if not user:
        raise HTTPException(status_code=401, detail="Identifiants incorrects")
    
    token = create_access_token({"sub": user["username"], "role": user["role"], "user_id": user["id"]})
    return LoginResponse(
        token=token,
        user={
            "id":             user["id"],
            "username":       user["username"],
            "role":           user["role"],
            "assigned_to_id": user.get("assigned_to_id"),
        }
    )

@router.get("/users")
async def get_users():
    """Récupérer la liste de tous les utilisateurs (admin seulement)"""
    try:
        users = get_all_users()
        return {"users": users, "total": len(users)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération des utilisateurs: {str(e)}")