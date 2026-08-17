"""Planificateur de tâches : rappels 20h et bilans mensuels automatiques"""
import asyncio
import logging
from datetime import datetime, timezone

from app.database import SessionLocal
from app.models.user import User
from app.routers.notifications import (
    create_notification,
    _get_reminder_settings,
    _has_entered_transaction_today,
)
from app.services.ai import ai_service

logger = logging.getLogger("afi.scheduler")

CHECK_INTERVAL_SECONDS = 60 * 60  # toutes les heures


def _reminder_due_for(user: User) -> bool:
    """Un rappel doit-il être envoyé à cet utilisateur aujourd'hui ?"""
    db = SessionLocal()
    try:
        settings = _get_reminder_settings(db, user.id)
        now = datetime.now(timezone.utc).replace(tzinfo=None)

        if not settings.reminder_enabled:
            return False
        if now.hour != settings.reminder_hour:
            return False
        is_weekend = now.weekday() >= 5
        if is_weekend and not settings.weekend_included:
            return False
        if _has_entered_transaction_today(db, user.id):
            return False
        return True
    finally:
        db.close()


def _run_daily_reminders():
    """Crée les notifications de rappel pour les utilisateurs concernés"""
    db = SessionLocal()
    try:
        users = db.query(User).all()
        for user in users:
            if _reminder_due_for(user):
                create_notification(
                    db, user.id,
                    "Rappel de saisie",
                    "Avez-vous saisi vos dépenses de la journée ?",
                    icon="alarm",
                )
                logger.info("Rappel créé pour l'utilisateur %s", user.id)
    finally:
        db.close()


def _run_monthly_reports():
    """Génère le bilan du mois précédent s'il n'existe pas (1er du mois)"""
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        if now.day != 1:
            return
        prev_year, prev_month = (now.year - 1, 12) if now.month == 1 else (now.year, now.month - 1)

        users = db.query(User).all()
        for user in users:
            report = ai_service.generate_monthly_report(db, user.id, prev_year, prev_month)
            if report:
                create_notification(
                    db, user.id,
                    "Bilan mensuel disponible",
                    f"Votre bilan de {prev_month:02d}/{prev_year} est prêt. Consultez-le pour mieux piloter vos finances.",
                    icon="assessment",
                )
                logger.info("Bilan mensuel généré pour l'utilisateur %s", user.id)
    finally:
        db.close()


async def scheduler_loop():
    """Boucle de planification (lancée au démarrage de l'app)"""
    logger.info("Planificateur AFI démarré")
    while True:
        try:
            _run_daily_reminders()
            _run_monthly_reports()
        except Exception as e:  # noqa: BLE001
            logger.error("Erreur planificateur : %s", e)
        await asyncio.sleep(CHECK_INTERVAL_SECONDS)