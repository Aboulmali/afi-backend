"""Modèle SavedAdvice - conseils IA sauvegardés et notés"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey

from app.database import Base


class SavedAdvice(Base):
    __tablename__ = "saved_advice"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(255), nullable=False)
    message = Column(String(1000), nullable=False)
    rating = Column(Integer, default=0)  # 0 = non noté, 1-5 étoiles
    created_at = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<SavedAdvice(id={self.id}, user_id={self.user_id})>"