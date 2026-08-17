"""Schémas pour l'authentification"""
from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserRegister(BaseModel):
    """Données pour l'inscription"""
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=100)
    full_name: str = Field(..., min_length=2, max_length=100)


class UserLogin(BaseModel):
    """Données pour la connexion"""
    email: EmailStr
    password: str


class Token(BaseModel):
    """Token JWT retourné"""
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Données extraites du token"""
    email: str | None = None


class UserResponse(BaseModel):
    """Réponse utilisateur (sans mot de passe)"""
    id: int
    email: str
    full_name: str

    model_config = ConfigDict(from_attributes=True)