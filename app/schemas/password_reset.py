"""Schémas pour la réinitialisation de mot de passe"""
from pydantic import BaseModel, EmailStr, Field


class ForgotPasswordRequest(BaseModel):
    """Demande de réinitialisation"""
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    """Réponse à la demande (dev : token dans la réponse)"""
    message: str
    reset_token: str | None = None


class ResetPasswordRequest(BaseModel):
    """Réinitialisation avec le token reçu par email"""
    token: str
    new_password: str = Field(..., min_length=8, max_length=100)