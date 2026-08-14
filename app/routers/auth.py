"""Endpoints d'authentification"""
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.password_reset import PasswordReset
from app.models.user import User
from app.schemas.auth import UserRegister, UserLogin, Token, UserResponse
from app.schemas.password_reset import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    ResetPasswordRequest,
)
from app.utils.security import hash_password, verify_password, create_access_token
from app.utils.dependencies import get_current_user
from app.utils.rate_limiter import login_limiter
from app.services.mailer import send_password_reset_email

router = APIRouter()


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """
    Inscription d'un nouvel utilisateur

    - **email** : Email valide
    - **password** : Mot de passe (min 8 caractères)
    - **full_name** : Nom complet
    """
    # Vérifier si l'email existe
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cet email est déjà utilisé"
        )

    # Créer l'utilisateur
    new_user = User(
        email=user_data.email,
        hashed_password=hash_password(user_data.password),
        full_name=user_data.full_name
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Générer le token
    access_token = create_access_token(data={"sub": new_user.email})

    return {
        "access_token": access_token,
        "token_type": "bearer"
    }


@router.post("/login", response_model=Token)
def login(
    credentials: UserLogin,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Connexion d'un utilisateur existant

    - **email** : Email
    - **password** : Mot de passe
    """
    # Anti brute-force : 5 tentatives / 5 min par IP + email
    host = request.client.host if request.client else "unknown"
    login_limiter.check(f"{host}:{credentials.email.lower()}")

    user = db.query(User).filter(User.email == credentials.email).first()

    if not user or not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect"
        )

    access_token = create_access_token(data={"sub": user.email})

    return {
        "access_token": access_token,
        "token_type": "bearer"
    }


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    """Récupère les informations de l'utilisateur connecté"""
    return current_user


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
def forgot_password(
    request: ForgotPasswordRequest,
    db: Session = Depends(get_db)
):
    """
    Demande de réinitialisation de mot de passe.
    En dev (DEBUG=True) le token est renvoyé dans la réponse.
    En production, envoyer le lien par email (service SMTP à brancher).
    """
    user = db.query(User).filter(User.email == request.email).first()
    if not user:
        # Ne pas révéler si l'email existe
        return ForgotPasswordResponse(message="Si cet email existe, un lien de réinitialisation a été envoyé")

    token = secrets.token_urlsafe(32)
    reset = PasswordReset(
        user_id=user.id,
        token=token,
        expires_at=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(hours=2),
    )
    db.add(reset)
    db.commit()

    # Envoi de l'email si SMTP est configuré (sinon token renvoyé en dev)
    reset_link = f"/reset-password?token={token}"
    email_sent = send_password_reset_email(user.email, reset_link)

    if email_sent:
        return ForgotPasswordResponse(message="Un email de réinitialisation a été envoyé")

    return ForgotPasswordResponse(
        message=f"SMTP non configuré. Lien de réinitialisation (valable 2h) : {reset_link}",
        reset_token=token if settings.DEBUG else None,
    )


@router.post("/reset-password")
def reset_password(
    request: ResetPasswordRequest,
    db: Session = Depends(get_db)
):
    """Réinitialise le mot de passe avec le token reçu"""
    reset = db.query(PasswordReset).filter(
        PasswordReset.token == request.token,
        PasswordReset.used == False,  # noqa: E712
    ).first()

    if not reset:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Token invalide")
    if reset.expires_at < datetime.now(timezone.utc).replace(tzinfo=None):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Token expiré")

    user = db.query(User).filter(User.id == reset.user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Utilisateur non trouvé")

    user.hashed_password = hash_password(request.new_password)
    reset.used = True
    db.commit()

    return {"message": "Mot de passe réinitialisé avec succès"}