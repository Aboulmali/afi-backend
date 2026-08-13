"""Service d'envoi d'emails (SMTP) pour la réinitialisation de mot de passe"""
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.config import settings


def send_email(to: str, subject: str, body: str) -> bool:
    """Envoie un email via SMTP si configuré, sinon False"""
    if not settings.SMTP_HOST:
        return False

    try:
        message = MIMEMultipart("alternative")
        message["From"] = settings.SMTP_FROM
        message["To"] = to
        message["Subject"] = subject
        message.attach(MIMEText(body, "plain", "utf-8"))

        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as server:
            server.starttls()
            if settings.SMTP_USER:
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(settings.SMTP_FROM, [to], message.as_string())
        return True
    except Exception:
        return False


def send_password_reset_email(to: str, reset_link: str) -> bool:
    """Email de réinitialisation de mot de passe"""
    subject = "AFI - Réinitialisation de votre mot de passe"
    body = (
        f"Bonjour,\n\n"
        f"Vous avez demandé la réinitialisation de votre mot de passe AFI.\n\n"
        f"Cliquez sur ce lien (valable 2 heures) :\n{reset_link}\n\n"
        f"Si vous n'êtes pas à l'origine de cette demande, ignorez cet email.\n\n"
        f"L'équipe AFI"
    )
    return send_email(to, subject, body)