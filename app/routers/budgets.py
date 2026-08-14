"""Endpoints des budgets avec alertes de dépassement"""
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.database import get_db
from app.models.budget import Budget
from app.models.budget_alert import BudgetAlert
from app.models.category import Category
from app.models.transaction import Transaction, TransactionType
from app.models.user import User
from app.schemas.budget import (
    BudgetCreate,
    BudgetUpdate,
    BudgetResponse,
    BudgetStatus,
)
from app.utils.dependencies import get_current_user
from app.routers.notifications import create_notification

router = APIRouter()


def _spent_for_category(db: Session, user_id: int, category_id: int, month: int, year: int) -> float:
    """Total dépensé pour une catégorie un mois donné"""
    return db.query(func.sum(Transaction.amount)).filter(
        Transaction.user_id == user_id,
        Transaction.category_id == category_id,
        Transaction.type == TransactionType.EXPENSE,
        func.extract('month', Transaction.transaction_date) == month,
        func.extract('year', Transaction.transaction_date) == year,
    ).scalar() or 0.0


def _record_alert(db: Session, user_id: int, budget: Budget, level: str, percentage: float):
    """Enregistre une alerte (une seule fois par niveau et par mois) et crée une notification"""
    exists = db.query(BudgetAlert).filter(
        BudgetAlert.user_id == user_id,
        BudgetAlert.budget_id == budget.id,
        BudgetAlert.level == level,
        func.extract('month', BudgetAlert.created_at) == datetime.now(timezone.utc).replace(tzinfo=None).month,
        func.extract('year', BudgetAlert.created_at) == datetime.now(timezone.utc).replace(tzinfo=None).year,
    ).first()
    if not exists:
        db.add(BudgetAlert(
            user_id=user_id,
            budget_id=budget.id,
            level=level,
            percentage=round(percentage, 1),
        ))
        db.commit()
        _notify_budget_alert(db, user_id, budget, level, percentage)


def _notify_budget_alert(db: Session, user_id: int, budget: Budget, level: str, percentage: float):
    """Crée une notification avec des suggestions de réduction des dépenses"""
    cat_name = budget.category.name if budget.category else "Cette catégorie"
    if level == "100":
        title = "Budget dépassé !"
        message = (
            f"Budget « {cat_name} » dépassé : {percentage:.0f}% consommé. "
            f"Coupez les dépenses non essentielles de cette catégorie (sorties, shopping) "
            f"et ajustez votre budget pour finir le mois."
        )
    else:
        title = "Sous tension sur votre budget"
        message = (
            f"Vous avez atteint {percentage:.0f}% du budget « {cat_name} » "
            f"({budget.amount:,.0f} F). Réduisez les dépenses non essentielles, "
            f"comparez les prix et privilégiez les achats groupés pour rester sous le plafond."
        )
    create_notification(db, user_id, title, message, icon="warning")


@router.post("", response_model=BudgetResponse, status_code=status.HTTP_201_CREATED)
def create_budget(
    budget_data: BudgetCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Définir un budget mensuel par catégorie"""
    category = db.query(Category).filter(Category.id == budget_data.category_id).first()
    if not category:
        raise HTTPException(status_code=404, detail="Catégorie non trouvée")

    existing = db.query(Budget).filter(
        Budget.user_id == current_user.id,
        Budget.category_id == budget_data.category_id,
        Budget.month == budget_data.month,
        Budget.year == budget_data.year,
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un budget existe déjà pour cette catégorie ce mois-ci"
        )

    budget = Budget(
        user_id=current_user.id,
        category_id=budget_data.category_id,
        amount=budget_data.amount,
        month=budget_data.month,
        year=budget_data.year,
    )
    db.add(budget)
    db.commit()
    db.refresh(budget)
    return budget


@router.get("", response_model=list[BudgetStatus])
def list_budgets(
    month: int | None = None,
    year: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Liste les budgets avec consommation et alertes 80%/100%"""
    query = db.query(Budget).filter(Budget.user_id == current_user.id)
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    month = month or now.month
    year = year or now.year
    query = query.filter(Budget.month == month, Budget.year == year)

    result = []
    for budget in query.all():
        spent = _spent_for_category(db, current_user.id, budget.category_id, month, year)
        percentage = (spent / budget.amount * 100) if budget.amount else 0.0
        if percentage >= 100:
            _record_alert(db, current_user.id, budget, "100", percentage)
        elif percentage >= 80:
            _record_alert(db, current_user.id, budget, "80", percentage)
        result.append(BudgetStatus(
            id=budget.id,
            category_id=budget.category_id,
            category_name=budget.category.name if budget.category else "?",
            amount=budget.amount,
            spent=spent,
            percentage=round(percentage, 1),
            alert_80=percentage >= 80,
            alert_100=percentage >= 100,
            remaining=round(budget.amount - spent, 2),
        ))
    return result


@router.put("/{budget_id}", response_model=BudgetResponse)
def update_budget(
    budget_id: int,
    budget_data: BudgetUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Modifie un budget"""
    budget = db.query(Budget).filter(
        Budget.id == budget_id,
        Budget.user_id == current_user.id
    ).first()
    if not budget:
        raise HTTPException(status_code=404, detail="Budget non trouvé")

    update_data = budget_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(budget, field, value)

    db.commit()
    db.refresh(budget)
    return budget


@router.get("/alerts", response_model=list[dict])
def list_alerts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Historique des alertes de dépassement de budget"""
    alerts = db.query(BudgetAlert).filter(
        BudgetAlert.user_id == current_user.id,
    ).order_by(BudgetAlert.created_at.desc()).limit(50).all()

    result = []
    for alert in alerts:
        budget = db.query(Budget).filter(Budget.id == alert.budget_id).first()
        cat = db.query(Category).filter(Category.id == budget.category_id).first() if budget else None
        result.append({
            "id": alert.id,
            "budget_id": alert.budget_id,
            "level": alert.level,
            "percentage": alert.percentage,
            "category_name": cat.name if cat else "?",
            "created_at": alert.created_at,
        })
    return result


@router.delete("/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_budget(
    budget_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Supprime un budget"""
    budget = db.query(Budget).filter(
        Budget.id == budget_id,
        Budget.user_id == current_user.id
    ).first()
    if not budget:
        raise HTTPException(status_code=404, detail="Budget non trouvé")

    db.delete(budget)
    db.commit()
    return None