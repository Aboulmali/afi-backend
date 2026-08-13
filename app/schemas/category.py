"""Schémas pour les catégories"""
from pydantic import BaseModel


class CategoryResponse(BaseModel):
    id: int
    name: str
    icon: str | None
    color: str | None

    class Config:
        from_attributes = True