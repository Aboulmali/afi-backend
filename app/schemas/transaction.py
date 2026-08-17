"""Schémas pour les transactions"""
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field
from app.models.transaction import TransactionType


class TransactionBase(BaseModel):
    """Base pour les transactions"""
    amount: float = Field(..., gt=0, description="Montant en FCFA")
    type: TransactionType
    description: str | None = None
    category_id: int


class TransactionCreate(TransactionBase):
    """Création d'une transaction"""
    transaction_date: datetime | None = None


class TransactionUpdate(BaseModel):
    """Modification d'une transaction"""
    amount: float | None = Field(None, gt=0)
    description: str | None = None
    category_id: int | None = None


class TransactionResponse(TransactionBase):
    """Réponse transaction"""
    id: int
    user_id: int
    transaction_date: datetime
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class BalanceResponse(BaseModel):
    """Réponse solde du dashboard"""
    balance: float
    total_income: float
    total_expenses: float
    month_income: float
    month_expenses: float


class MonthStatsResponse(BaseModel):
    """Statistiques du mois courant"""
    month: int
    year: int
    total_expenses: float
    total_income: float
    balance: float
    daily_average: float
    top_category_id: int | None
    top_category_name: str | None
    top_category_amount: float
    previous_month_expenses: float
    previous_month_income: float
    expenses_change_percent: float | None
    income_change_percent: float | None


class CategorySpending(BaseModel):
    """Dépense par catégorie pour un graphique"""
    category_id: int
    category_name: str
    color: str | None
    amount: float
    percentage: float


class MonthlyPoint(BaseModel):
    """Point mensuel pour le graphique d'évolution"""
    month: int
    year: int
    label: str
    expenses: float
    income: float


class SpendingChartResponse(BaseModel):
    """Réponse graphique de dépenses par catégorie"""
    period: str
    total: float
    categories: list[CategorySpending]