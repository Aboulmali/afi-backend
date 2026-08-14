"""Endpoints scan de factures (OCR)"""
import os
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.pending_scan import PendingScan
from app.models.transaction import Transaction, TransactionType
from app.models.user import User
from app.services.ocr import InvoiceScanner
from app.services.storage import delete as storage_delete
from app.services.storage import upload as storage_upload
from app.utils.dependencies import get_current_user

router = APIRouter()

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

_scanner = None


def _get_scanner() -> InvoiceScanner:
    global _scanner
    if _scanner is None:
        _scanner = InvoiceScanner()
    return _scanner


@router.post("/scan")
async def scan_invoice(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Scan d'une facture (photo) : extraction montant, date, commerçant, catégorie.
    Le résultat est gardé en attente de validation par l'utilisateur.
    """
    try:
        scanner = _get_scanner()
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Le fichier doit être une image")

    path = os.path.join(UPLOAD_DIR, f"{uuid.uuid4()}.jpg")
    stored_key = None
    try:
        content = await file.read()
        with open(path, "wb") as f:
            f.write(content)

        stored_key, _ = storage_upload(content, file.content_type)

        result = scanner.scan(path)

        pending = PendingScan(
            user_id=current_user.id,
            merchant=result["merchant"],
            amount=str(result["amount"]) if result["amount"] is not None else None,
            raw_amount=result["amount_raw"],
            date=result["date"],
            suggested_category_id=result["suggested_category_id"],
            ocr_text="\n".join(result["texts"]),
        )
        db.add(pending)
        db.commit()
        db.refresh(pending)

        return {
            "pending_id": pending.id,
            "merchant": result["merchant"],
            "merchant_confidence": result["merchant_confidence"],
            "amount": result["amount"],
            "amount_raw": result["amount_raw"],
            "date": result["date"],
            "suggested_category_id": result["suggested_category_id"],
            "suggested_category": result["suggested_category"],
            "message": "Vérifiez les informations puis confirmez la transaction",
        }
    finally:
        if os.path.exists(path):
            os.remove(path)
        if stored_key:
            storage_delete(stored_key)


@router.get("/scan/pending", response_model=list[dict])
def list_pending_scans(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Scans en attente de validation"""
    rows = db.query(PendingScan).filter(
        PendingScan.user_id == current_user.id,
    ).order_by(PendingScan.created_at.desc()).limit(20).all()

    return [{
        "pending_id": r.id,
        "merchant": r.merchant,
        "amount": float(r.amount) if r.amount else None,
        "raw_amount": r.raw_amount,
        "date": r.date,
        "suggested_category_id": r.suggested_category_id,
    } for r in rows]


@router.post("/scan/{pending_id}/confirm")
def confirm_scan(
    pending_id: int,
    category_id: int | None = None,
    amount: float | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Valide le scan et crée la transaction (montant/catégorie ajustables)"""
    pending = db.query(PendingScan).filter(
        PendingScan.id == pending_id,
        PendingScan.user_id == current_user.id,
    ).first()
    if not pending:
        raise HTTPException(status_code=404, detail="Scan non trouvé")

    final_amount = amount if amount is not None else (float(pending.amount) if pending.amount else None)
    if not final_amount or final_amount <= 0:
        raise HTTPException(status_code=400, detail="Montant invalide")

    transaction = Transaction(
        user_id=current_user.id,
        category_id=category_id or pending.suggested_category_id,
        amount=final_amount,
        type=TransactionType.EXPENSE,
        description=f"Scan facture - {pending.merchant}" if pending.merchant else "Scan facture",
        transaction_date=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(transaction)
    db.delete(pending)
    db.commit()
    db.refresh(transaction)

    return {"message": "Transaction créée", "transaction_id": transaction.id, "amount": final_amount}


@router.delete("/scan/{pending_id}", status_code=204)
def discard_scan(
    pending_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Annule le scan (mauvaise photo, etc.)"""
    pending = db.query(PendingScan).filter(
        PendingScan.id == pending_id,
        PendingScan.user_id == current_user.id,
    ).first()
    if not pending:
        raise HTTPException(status_code=404, detail="Scan non trouvé")

    db.delete(pending)
    db.commit()
    return None