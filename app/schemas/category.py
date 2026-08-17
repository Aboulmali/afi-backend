"""Schémas pour les catégories"""
from pydantic import BaseModel, ConfigDict


class CategoryResponse(BaseModel):
    id: int
    name: str
    icon: str | None
    color: str | None

    model_config = ConfigDict(from_attributes=True)