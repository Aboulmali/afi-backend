"""Modèle MonthlyReport - bilans mensuels générés par l'IA"""
from datetime import datetime
from sqlalchemy import Column, Integer, Text, DateTime, ForeignKey

from app.database import Base


class MonthlyReport(Base):
    __tablename__ = "monthly_reports"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    month = Column(Integer, nullable=False)  # 1-12
    year = Column(Integer, nullable=False)
    summary = Column(Text, nullable=False)
    insights_json = Column(Text, default="[]")
    created_at = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<MonthlyReport(user_id={self.user_id}, month={self.month})>"