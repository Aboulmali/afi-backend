"""Endpoints des notifications et rappels de saisie"""
import json
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.notification import Notification
from app.models.transaction import Transaction
from app.models.user import User
from app.models.user_preference import UserPreference
from app.schemas.notifications import (
    NotificationResponse,
    ReminderSettings,
)
from app.utils.dependencies import get_current_user

router = APIRouter()

SETTINGS_KEY = "reminder_settings"


def create_notification(db: Session, user_id: int, title: str, message: str, icon: str = "notifications") -> Notification:
    """Crée une notification dans la base (sera poussée par le service push)"""
    notification = Notification(
        user_id=user_id,
        title=title,
        message=message,
        icon=icon,
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return notification


def _has_entered_transaction_today(db: Session, user_id: int) -> bool:
    """Vrai si l'utilisateur a déjà saisi une transaction aujourd'hui"""
    now = datetime.utcnow()
    start = datetime(now.year, now.month, now.day)
    return db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.transaction_date >= start,
    ).first() is not None


def _get_reminder_settings(db: Session, user_id: int) -> ReminderSettings:
    pref = db.query(UserPreference).filter(
        UserPreference.user_id == user_id,
        UserPreference.key == SETTINGS_KEY,
    ).first()
    if not pref or not pref.value:
        return ReminderSettings()
    try:
        return ReminderSettings(**json.loads(pref.value))
    except Exception:
        return ReminderSettings()


def _save_reminder_settings(db: Session, user_id: int, settings: ReminderSettings) -> ReminderSettings:
    pref = db.query(UserPreference).filter(
        UserPreference.user_id == user_id,
        UserPreference.key == SETTINGS_KEY,
    ).first()
    if not pref:
        pref = UserPreference(user_id=user_id, key=SETTINGS_KEY, value=settings.model_dump_json())
        db.add(pref)
    else:
        pref.value = settings.model_dump_json()
    db.commit()
    return settings


@router.get("", response_model=list[NotificationResponse])
def list_notifications(
    filter: str = Query("all", pattern="^(all|unread|read)$"),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Liste les notifications (toutes / non lues / lues)"""
    query = db.query(Notification).filter(Notification.user_id == current_user.id)
    if filter == "unread":
        query = query.filter(Notification.read == False)  # noqa: E712
    elif filter == "read":
        query = query.filter(Notification.read == True)  # noqa: E712

    notifications = query.order_by(Notification.created_at.desc()).limit(limit).all()
    return notifications


@router.put("/{notification_id}/read", response_model=NotificationResponse)
def mark_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Marque une notification comme lue"""
    notification = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == current_user.id,
    ).first()
    if not notification:
        raise HTTPException(status_code=404, detail="Notification non trouvée")

    notification.read = True
    db.commit()
    db.refresh(notification)
    return notification


@router.put("/read-all")
def mark_all_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Marque toutes les notifications comme lues"""
    db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.read == False,  # noqa: E712
    ).update({"read": True})
    db.commit()
    return {"message": "Toutes les notifications sont lues"}


@router.get("/settings", response_model=ReminderSettings)
def get_settings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Réglages du rappel de saisie quotidienne"""
    return _get_reminder_settings(db, current_user.id)


@router.put("/settings", response_model=ReminderSettings)
def update_settings(
    settings: ReminderSettings,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Modifie les réglages du rappel (heure, activation, weekend)"""
    return _save_reminder_settings(db, current_user.id, settings)


@router.get("/reminders/due")
def get_due_reminders(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Rappels à envoyer aujourd'hui (appelé par le planificateur à 20h) :
    - Le rappel est activé
    - L'utilisateur n'a pas déjà saisi de transaction aujourd'hui
    - Le weekend est exclu si réglé ainsi
    """
    settings = _get_reminder_settings(db, current_user.id)
    now = datetime.utcnow()

    if not settings.reminder_enabled:
        return {"send": False, "reason": "rappel désactivé"}

    is_weekend = now.weekday() >= 5
    if is_weekend and not settings.weekend_included:
        return {"send": False, "reason": "weekend exclu"}

    if _has_entered_transaction_today(db, current_user.id):
        return {"send": False, "reason": "déjà saisi aujourd'hui"}

    return {
        "send": True,
        "hour": settings.reminder_hour,
        "message": "Avez-vous saisi vos dépenses de la journée ?",
    }