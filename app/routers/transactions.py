"""Endpoints des transactions"""
import json
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.database import get_db
from app.models.transaction import Transaction, TransactionType
from app.models.user import User
from app.models.user_preference import UserPreference
from app.schemas.transaction import (
    TransactionCreate,
    TransactionUpdate,
    TransactionResponse
)
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.post("", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(
    transaction_data: TransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Créer une nouvelle transaction"""
    new_transaction = Transaction(
        user_id=current_user.id,
        category_id=transaction_data.category_id,
        amount=transaction_data.amount,
        type=transaction_data.type,
        description=transaction_data.description,
        transaction_date=transaction_data.transaction_date or datetime.utcnow()
    )

    db.add(new_transaction)
    db.commit()
    db.refresh(new_transaction)

    return new_transaction


@router.get("", response_model=list[TransactionResponse])
def list_transactions(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    type: TransactionType | None = None,
    category_id: int | None = None,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    search: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    response: Response = None
):
    """Liste les transactions de l'utilisateur, filtres combinables :
    type, catégorie, période (start_date/end_date), recherche texte.
    Header X-Total-Count : nombre total de résultats (pour la pagination)."""
    query = db.query(Transaction).filter(Transaction.user_id == current_user.id)

    if type:
        query = query.filter(Transaction.type == type)
    if category_id:
        query = query.filter(Transaction.category_id == category_id)
    if start_date:
        query = query.filter(Transaction.transaction_date >= start_date)
    if end_date:
        query = query.filter(Transaction.transaction_date <= end_date)
    if search:
        query = query.filter(Transaction.description.ilike(f"%{search}%"))

    total = query.count()
    if response is not None:
        response.headers["X-Total-Count"] = str(total)

    transactions = query.order_by(desc(Transaction.transaction_date)).offset(skip).limit(limit).all()
    return transactions


@router.get("/filters/preferences")
def get_filter_preferences(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Derniers filtres utilisés (sauvegardés côté serveur)"""
    pref = db.query(UserPreference).filter(
        UserPreference.user_id == current_user.id,
        UserPreference.key == "last_transaction_filters",
    ).first()
    if not pref or not pref.value:
        return {}
    try:
        return json.loads(pref.value)
    except Exception:
        return {}


@router.put("/filters/preferences")
def save_filter_preferences(
    filters: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Sauvegarde les derniers filtres utilisés par l'utilisateur"""
    pref = db.query(UserPreference).filter(
        UserPreference.user_id == current_user.id,
        UserPreference.key == "last_transaction_filters",
    ).first()
    if not pref:
        pref = UserPreference(
            user_id=current_user.id,
            key="last_transaction_filters",
            value=json.dumps(filters, ensure_ascii=False),
        )
        db.add(pref)
    else:
        pref.value = json.dumps(filters, ensure_ascii=False)
    db.commit()
    return {"message": "Filtres sauvegardés"}


@router.get("/{transaction_id}", response_model=TransactionResponse)
def get_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Récupère une transaction spécifique"""
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id
    ).first()

    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction non trouvée")

    return transaction


@router.put("/{transaction_id}", response_model=TransactionResponse)
def update_transaction(
    transaction_id: int,
    transaction_data: TransactionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Modifie une transaction"""
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id
    ).first()

    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction non trouvée")

    update_data = transaction_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(transaction, field, value)

    db.commit()
    db.refresh(transaction)
    return transaction


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Supprime une transaction"""
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id
    ).first()

    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction non trouvée")

    db.delete(transaction)
    db.commit()
    return None