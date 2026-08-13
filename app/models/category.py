"""Modèle Category"""
from sqlalchemy import Column, Integer, String

from app.database import Base


class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False)
    icon = Column(String(50))  # Nom de l'icône Material
    color = Column(String(7))  # Code hexadécimal #RRGGBB

    def __repr__(self):
        return f"<Category(id={self.id}, name={self.name})>"