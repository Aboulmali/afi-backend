"""Endpoints du dashboard"""
from datetime import datetime, timedelta, timezone
from calendar import monthrange
from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.category import Category
from app.models.transaction import Transaction, TransactionType
from app.models.user import User
from app.schemas.transaction import (
    BalanceResponse,
    MonthStatsResponse,
    CategorySpending,
    MonthlyPoint,
    SpendingChartResponse,
)
from app.services import cache
from app.utils.dependencies import get_current_user

router = APIRouter()


def _sum_between(db: Session, user_id: int, tx_type: TransactionType, start: datetime, end: datetime) -> float:
    return db.query(func.sum(Transaction.amount)).filter(
        Transaction.user_id == user_id,
        Transaction.type == tx_type,
        Transaction.transaction_date >= start,
        Transaction.transaction_date < end,
    ).scalar() or 0.0


@router.get("/balance", response_model=BalanceResponse)
def get_balance(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Récupère le solde et les stats de l'utilisateur (cache Redis 60 s)"""
    cached = cache.get(current_user.id, "balance")
    if cached is not None:
        return cached

    # Total recettes
    total_income = db.query(func.sum(Transaction.amount)).filter(
        Transaction.user_id == current_user.id,
        Transaction.type == TransactionType.INCOME
    ).scalar() or 0.0

    # Total dépenses
    total_expenses = db.query(func.sum(Transaction.amount)).filter(
        Transaction.user_id == current_user.id,
        Transaction.type == TransactionType.EXPENSE
    ).scalar() or 0.0

    # Stats du mois courant
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    month_income = db.query(func.sum(Transaction.amount)).filter(
        Transaction.user_id == current_user.id,
        Transaction.type == TransactionType.INCOME,
        func.extract('month', Transaction.transaction_date) == now.month,
        func.extract('year', Transaction.transaction_date) == now.year
    ).scalar() or 0.0

    month_expenses = db.query(func.sum(Transaction.amount)).filter(
        Transaction.user_id == current_user.id,
        Transaction.type == TransactionType.EXPENSE,
        func.extract('month', Transaction.transaction_date) == now.month,
        func.extract('year', Transaction.transaction_date) == now.year
    ).scalar() or 0.0

    data = {
        "balance": total_income - total_expenses,
        "total_income": total_income,
        "total_expenses": total_expenses,
        "month_income": month_income,
        "month_expenses": month_expenses
    }
    cache.set_cache(current_user.id, "balance", data)
    return data


def _month_bounds(year: int, month: int) -> tuple[datetime, datetime]:
    """Borne début [n, m) du mois"""
    start = datetime(year, month, 1)
    _, last_day = monthrange(year, month)
    end = datetime(year, month, last_day) + timedelta(days=1)
    return start, end


def _month_label(year: int, month: int) -> str:
    months = ["Jan", "Fév", "Mar", "Avr", "Mai", "Juin",
              "Juil", "Août", "Sep", "Oct", "Nov", "Déc"]
    return f"{months[month - 1]} {year}"


@router.get("/stats", response_model=MonthStatsResponse)
def get_month_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Statistiques du mois courant + comparaison mois précédent
    (cache Redis 60 s)"""
    cached = cache.get(current_user.id, "stats")
    if cached is not None:
        return MonthStatsResponse(**cached)

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    start, end = _month_bounds(now.year, now.month)

    total_expenses = _sum_between(db, current_user.id, TransactionType.EXPENSE, start, end)
    total_income = _sum_between(db, current_user.id, TransactionType.INCOME, start, end)

    last_day = end - timedelta(days=1)
    daily_average = round(total_expenses / last_day.day, 2)

    top = db.query(
        Transaction.category_id,
        func.sum(Transaction.amount).label("total")
    ).filter(
        Transaction.user_id == current_user.id,
        Transaction.type == TransactionType.EXPENSE,
        Transaction.transaction_date >= start,
        Transaction.transaction_date < end,
    ).group_by(Transaction.category_id).order_by(func.sum(Transaction.amount).desc()).first()

    top_category = None
    top_amount = 0.0
    if top:
        cat = db.query(Category).filter(Category.id == top.category_id).first()
        top_category = cat
        top_amount = top.total or 0.0

    # Mois précédent
    prev_year, prev_month = (now.year - 1, 12) if now.month == 1 else (now.year, now.month - 1)
    p_start, p_end = _month_bounds(prev_year, prev_month)
    prev_expenses = _sum_between(db, current_user.id, TransactionType.EXPENSE, p_start, p_end)
    prev_income = _sum_between(db, current_user.id, TransactionType.INCOME, p_start, p_end)

    def pct(cur: float, prev: float) -> float | None:
        if prev == 0:
            return None
        return round((cur - prev) / prev * 100, 1)

    data = MonthStatsResponse(
        month=now.month,
        year=now.year,
        total_expenses=round(total_expenses, 2),
        total_income=round(total_income, 2),
        balance=round(total_income - total_expenses, 2),
        daily_average=daily_average,
        top_category_id=top_category.id if top_category else None,
        top_category_name=top_category.name if top_category else None,
        top_category_amount=round(top_amount, 2),
        previous_month_expenses=round(prev_expenses, 2),
        previous_month_income=round(prev_income, 2),
        expenses_change_percent=pct(total_expenses, prev_expenses),
        income_change_percent=pct(total_income, prev_income),
    )
    cache.set_cache(current_user.id, "stats", data.model_dump())
    return data


@router.get("/spending", response_model=SpendingChartResponse)
def get_spending_by_category(
    period: str = Query("month", pattern="^(week|month|year)$"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Dépenses par catégorie pour un graphique circulaire (semaine/mois/année)"""
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    if period == "week":
        start = now - timedelta(days=now.weekday())
    elif period == "year":
        start = datetime(now.year, 1, 1)
    else:
        start, _ = _month_bounds(now.year, now.month)

    rows = db.query(
        Transaction.category_id,
        func.sum(Transaction.amount).label("total")
    ).filter(
        Transaction.user_id == current_user.id,
        Transaction.type == TransactionType.EXPENSE,
        Transaction.transaction_date >= start,
    ).group_by(Transaction.category_id).all()

    total = sum(r.total or 0.0 for r in rows)
    categories = []
    for row in rows:
        cat = db.query(Category).filter(Category.id == row.category_id).first()
        amount = row.total or 0.0
        categories.append(CategorySpending(
            category_id=row.category_id,
            category_name=cat.name if cat else "?",
            color=cat.color if cat else None,
            amount=round(amount, 2),
            percentage=round(amount / total * 100, 1) if total else 0.0,
        ))
    categories.sort(key=lambda c: c.amount, reverse=True)

    return SpendingChartResponse(
        period=period,
        total=round(total, 2),
        categories=categories,
    )


@router.get("/evolution", response_model=list[MonthlyPoint])
def get_evolution(
    months: int = Query(6, ge=3, le=24),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Évolution mensuelle des dépenses et recettes (6 derniers mois)"""
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    points = []
    for i in range(months - 1, -1, -1):
        year = now.year
        month = now.month - i
        while month <= 0:
            month += 12
            year -= 1
        start, end = _month_bounds(year, month)
        expenses = _sum_between(db, current_user.id, TransactionType.EXPENSE, start, end)
        income = _sum_between(db, current_user.id, TransactionType.INCOME, start, end)
        points.append(MonthlyPoint(
            month=month,
            year=year,
            label=_month_label(year, month),
            expenses=round(expenses, 2),
            income=round(income, 2),
        ))
    return points