"""Modèle ChatMessage - historique des conversations avec l'IA"""
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey

from app.database import Base


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    conversation_id = Column(String(50), index=True, nullable=False)
    role = Column(String(20), nullable=False)  # user | assistant
    content = Column(String(5000), nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc).replace(tzinfo=None))

    def __repr__(self):
        return f"<ChatMessage(id={self.id}, role={self.role})>"