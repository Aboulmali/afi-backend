"""Sauvegarde temporaire des scans avant validation"""
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey

from app.database import Base


class PendingScan(Base):
    __tablename__ = "pending_scans"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    merchant = Column(String(255))
    amount = Column(String(50))      # gardé en chaîne avant validation
    raw_amount = Column(String(255))
    date = Column(String(30))
    suggested_category_id = Column(Integer)
    ocr_text = Column(String(5000), default="")
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc).replace(tzinfo=None))

    def __repr__(self):
        return f"<PendingScan(id={self.id}, user_id={self.user_id})>"