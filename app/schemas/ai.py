"""Schémas pour l'assistant IA"""
from datetime import datetime
from pydantic import BaseModel


class AIInsight(BaseModel):
    """Insight automatique sur les habitudes financières"""
    id: int
    title: str
    message: str
    severity: str  # info | warning | danger | success
    date: datetime


class AIAdvice(BaseModel):
    """Conseil personnalisé"""
    id: int
    title: str
    message: str
    saved: bool


class ChatRequest(BaseModel):
    """Question posée à l'assistant"""
    message: str


class ChatMessage(BaseModel):
    """Message de l'assistant"""
    role: str  # user | assistant
    content: str
    timestamp: datetime


class ChatResponse(BaseModel):
    """Réponse du chat"""
    reply: str
    conversation_id: str | None = None


class VoiceChatResponse(BaseModel):
    """Réponse du chat vocal (transcription + réponse)"""
    transcribed: str
    reply: str
    conversation_id: str | None = None


class SaveAdviceRequest(BaseModel):
    """Sauvegarde d'un conseil"""
    title: str
    message: str


class SavedAdviceResponse(BaseModel):
    """Conseil sauvegardé"""
    id: int
    title: str
    message: str
    rating: int
    created_at: datetime

    class Config:
        from_attributes = True


class RateAdviceRequest(BaseModel):
    """Notation de pertinence d'un conseil sauvegardé"""
    rating: int  # 1-5


class ChatMessageResponse(BaseModel):
    """Message d'historique de conversation"""
    id: int
    role: str
    content: str
    created_at: datetime

    class Config:
        from_attributes = True


class MonthlyReportResponse(BaseModel):
    """Bilan mensuel généré par l'IA"""
    id: int
    month: int
    year: int
    summary: str
    insights: list[str]
    created_at: datetime


class InsightHistoryResponse(BaseModel):
    """Insight consulté (historique)"""
    id: int
    title: str
    message: str
    severity: str
    viewed_at: datetime

    class Config:
        from_attributes = True