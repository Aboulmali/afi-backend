"""Import de tous les modèles pour SQLAlchemy"""
from app.models.user import User
from app.models.category import Category
from app.models.transaction import Transaction, TransactionType
from app.models.budget import Budget
from app.models.password_reset import PasswordReset
from app.models.notification import Notification
from app.models.saved_advice import SavedAdvice
from app.models.chat_message import ChatMessage
from app.models.budget_alert import BudgetAlert
from app.models.user_preference import UserPreference
from app.models.monthly_report import MonthlyReport
from app.models.pending_scan import PendingScan
from app.models.insight_view import InsightView

__all__ = [
    "User", "Category", "Transaction", "TransactionType", "Budget",
    "PasswordReset", "Notification", "SavedAdvice", "ChatMessage",
    "BudgetAlert", "UserPreference", "MonthlyReport", "PendingScan",
    "InsightView",
]