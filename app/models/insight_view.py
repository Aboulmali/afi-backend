"""Modèle InsightView - historique des insights consultés"""
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey

from app.database import Base


class InsightView(Base):
    __tablename__ = "insight_views"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(255), nullable=False)
    message = Column(String(2000), nullable=False)
    severity = Column(String(20), default="info")
    viewed_at = Column(DateTime, default=lambda: datetime.now(timezone.utc).replace(tzinfo=None))

    def __repr__(self):
        return f"<InsightView(id={self.id}, user_id={self.user_id})>"