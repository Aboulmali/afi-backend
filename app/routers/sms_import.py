"""Endpoints d'import automatique de transactions depuis les SMS bancaires"""
import re
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.transaction import Transaction, TransactionType
from app.models.user import User
from app.utils.dependencies import get_current_user

router = APIRouter()


class BankSms(BaseModel):
    """SMS bancaire envoyé par l'app mobile (permission SMS côté Android)"""
    sender: str
    body: str
    received_at: datetime | None = None


class SmsImportRequest(BaseModel):
    messages: list[BankSms] = Field(..., min_length=1)


class ParsedSms(BaseModel):
    """Transaction extraite d'un SMS"""
    amount: float
    type: Literal["debit", "credit"]
    description: str
    date: datetime | None
    confidence: float  # 0-1
    bank: str | None


class SmsImportResponse(BaseModel):
    parsed: list[ParsedSms]
    ignored: int


class ConfirmImportItem(BaseModel):
    """Transaction à créer après validation utilisateur"""
    amount: float = Field(..., gt=0)
    type: TransactionType
    description: str
    category_id: int
    date: datetime | None = None


class ConfirmImportRequest(BaseModel):
    items: list[ConfirmImportItem]


BANK_KEYWORDS = {
    "om": "Orange Money",
    "orange": "Orange Money",
    "wv": "Wave",
    "wave": "Wave",
    "free": "Free Money",
    "cbao": "CBAO",
    "bhs": "BHS",
    "sgbs": "SGBS",
    "ecobank": "Ecobank",
}


def _parse_amount(body: str) -> float | None:
    """Montant : '3000 F', '2.500 FCFA', '10 000 FCFA', 'XOF' etc."""
    patterns = [
        r"([0-9][0-9\s.,]*)\s*(?:f\s*cfa|fcfa|xof|francs?|fr\b)",
        r"(?:montant|somme|total)\s*[:=]?\s*([0-9][0-9\s.,]*)",
        r"(?:debiter|crediter)de\s*([0-9][0-9\s.,]*)",
    ]
    for pattern in patterns:
        match = re.search(pattern, body, re.IGNORECASE)
        if match:
            raw = match.group(1).strip().replace(" ", "").replace("\u00a0", "")
            if "," in raw and "." in raw:
                raw = raw.replace(",", "") if raw.rfind(".") > raw.rfind(",") else raw.replace(".", "")
            elif "," in raw:
                raw = raw.replace(",", ".")
            try:
                value = float(raw)
                if value > 0:
                    return value
            except ValueError:
                continue
    return None


def _is_bank_sms(sender: str) -> bool:
    lower = sender.lower()
    return any(k in lower for k in BANK_KEYWORDS)


def _detect_bank(sender: str) -> str | None:
    lower = sender.lower()
    for key, name in BANK_KEYWORDS.items():
        if key in lower:
            return name
    return None


def _parse_one(sms: BankSms) -> ParsedSms | None:
    """Analyse un SMS bancaire -> transaction proposée"""
    if not _is_bank_sms(sms.sender):
        return None

    bank = _detect_bank(sms.sender)
    amount = _parse_amount(sms.body)
    if amount is None:
        return None

    lower = sms.body.lower()
    is_debit = any(k in lower for k in [
        "debit", "debite", "retrait", "paiement", "achat", "transfert envoye",
        "debiter", "prelevement", "prelevé", "facture",
        "a ete debite", "a été débité", "vous avez paye", "vous avez payé",
    ])
    is_credit = any(k in lower for k in [
        "credit", "credited", "recu", "reception", "virement recu", "virement reçu",
        "versement", "depot", "a ete credite", "a été crédité",
    ])

    tx_type: Literal["debit", "credit"]
    if is_credit:
        tx_type = "credit"
    elif is_debit:
        tx_type = "debit"
    else:
        return None

    date = None
    match = re.search(r"\b(\d{2}/\d{2}/\d{4}|\d{2}/\d{2}/\d{2})\b", sms.body)
    if match:
        try:
            date = datetime.strptime(match.group(1), "%d/%m/%Y")
        except ValueError:
            try:
                date = datetime.strptime(match.group(1), "%d/%m/%y")
            except ValueError:
                date = None

    # Description : contenu après le montant ou texte court significatif
    description = sms.body[:80].replace("\n", " ").strip()
    confidence = 0.5 + min(0.5, amount / 100000)

    return ParsedSms(
        amount=amount,
        type=tx_type,
        description=description,
        date=date,
        confidence=round(confidence, 2),
        bank=bank,
    )


@router.post("/sms/parse", response_model=SmsImportResponse)
def parse_sms(
    request: SmsImportRequest,
    db: Session = Depends(get_db)
):
    """
    Reçoit les SMS lus par l'app mobile et propose des transactions.
    Rien n'est enregistré : l'utilisateur valide ensuite via /sms/confirm.
    """
    parsed = []
    ignored = 0
    for sms in request.messages:
        item = _parse_one(sms)
        if item:
            parsed.append(item)
        else:
            ignored += 1
    return SmsImportResponse(parsed=parsed, ignored=ignored)


@router.post("/sms/confirm")
def confirm_sms_import(
    request: ConfirmImportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Crée les transactions validées par l'utilisateur puis notifie"""
    created = []
    for item in request.items:
        transaction = Transaction(
            user_id=current_user.id,
            category_id=item.category_id,
            amount=item.amount,
            type=item.type,
            description=f"[SMS] {item.description}"[:255],
            transaction_date=item.date or datetime.now(timezone.utc).replace(tzinfo=None),
        )
        db.add(transaction)
        db.commit()
        db.refresh(transaction)
        created.append(transaction.id)

    from app.routers.notifications import create_notification
    create_notification(
        db, current_user.id,
        "Import SMS terminé",
        f"{len(created)} transaction(s) créée(s) automatiquement à partir de vos SMS.",
        icon="sms",
    )

    return {"message": f"{len(created)} transactions créées", "transaction_ids": created}