"""Schémas pour les budgets"""
from datetime import datetime
from pydantic import BaseModel, Field


class BudgetBase(BaseModel):
    """Base budget"""
    category_id: int
    amount: float = Field(..., gt=0, description="Montant du budget")
    month: int = Field(..., ge=1, le=12)
    year: int = Field(..., ge=2000, le=2100)


class BudgetCreate(BudgetBase):
    """Création d'un budget"""


class BudgetUpdate(BaseModel):
    """Modification d'un budget"""
    amount: float | None = Field(None, gt=0)
    month: int | None = Field(None, ge=1, le=12)
    year: int | None = Field(None, ge=2000, le=2100)


class BudgetResponse(BudgetBase):
    """Réponse budget"""
    id: int
    user_id: int
    created_at: datetime

    class Config:
        from_attributes = True


class BudgetStatus(BaseModel):
    """Statut d'un budget avec les alertes"""
    id: int
    category_id: int
    category_name: str
    amount: float
    spent: float
    percentage: float
    alert_80: bool  # 80% atteint
    alert_100: bool  # 100% atteint (dépassé)
    remaining: float