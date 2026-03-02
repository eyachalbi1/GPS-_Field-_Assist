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
    id: str
    reference: str
    name: str
    description: str
    partner_name: str
    start_time: str
    end_time: str
    status: str

