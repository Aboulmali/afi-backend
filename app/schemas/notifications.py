"""Schémas pour les notifications"""
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class NotificationCreate(BaseModel):
    """Création d'une notification (interne)"""
    title: str
    message: str
    icon: str = "notifications"


class NotificationResponse(BaseModel):
    """Réponse notification"""
    id: int
    title: str
    message: str
    icon: str
    read: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ReminderSettings(BaseModel):
    """Réglages du rappel de saisie quotidienne"""
    reminder_enabled: bool = True
    reminder_hour: int = 20  # 0-23
    weekend_included: bool = False

    model_config = ConfigDict(from_attributes=True)