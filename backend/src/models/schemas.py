# src/models/schemas.py
from pydantic import BaseModel
from typing import Optional

class LoginRequest(BaseModel):
    username: str
    password: str

class LoginResponse(BaseModel):
    token: str
    user: dict

class TaskResponse(BaseModel):
    id:           str
    subject:      str
    description:  str
    partner_name: str
    start_time:   str
    end_time:     str
    stage:        str
    assigned_to:  Optional[str] = None
    created_at:   Optional[str] = None

