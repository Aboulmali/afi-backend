"""Endpoints de l'assistant IA"""
import io
import uuid
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.chat_message import ChatMessage
from app.models.insight_view import InsightView
from app.models.saved_advice import SavedAdvice
from app.models.user import User
from app.schemas.ai import (
    AIAdvice,
    AIInsight,
    ChatRequest,
    ChatResponse,
    ChatMessageResponse,
    InsightHistoryResponse,
    MonthlyReportResponse,
    RateAdviceRequest,
    SaveAdviceRequest,
    SavedAdviceResponse,
    VoiceChatResponse,
)
from app.services.ai import ai_service, CHAT_SUGGESTIONS
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get("/insights", response_model=list[AIInsight])
def get_insights(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Insights automatiques sur les habitudes financières (ajoutés à l'historique)"""
    insights = ai_service.generate_insights(db, current_user.id)

    # Historique des insights consultés (sans doublon le même jour)
    today_start = datetime.utcnow() - timedelta(hours=24)
    for ins in insights:
        already = db.query(InsightView).filter(
            InsightView.user_id == current_user.id,
            InsightView.title == ins["title"],
            InsightView.message == ins["message"],
            InsightView.viewed_at >= today_start,
        ).first()
        if not already:
            db.add(InsightView(
                user_id=current_user.id,
                title=ins["title"],
                message=ins["message"],
                severity=ins["severity"],
            ))
    db.commit()
    return insights


@router.get("/insights/history", response_model=list[InsightHistoryResponse])
def get_insights_history(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Historique des insights consultés"""
    return db.query(InsightView).filter(
        InsightView.user_id == current_user.id,
    ).order_by(InsightView.viewed_at.desc()).limit(limit).all()


@router.get("/advice", response_model=list[AIAdvice])
def get_advice(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Conseils personnalisés de l'IA"""
    return ai_service.generate_advice(db, current_user.id)


@router.post("/advice/save", response_model=SavedAdviceResponse, status_code=status.HTTP_201_CREATED)
def save_advice(
    request: SaveAdviceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Sauvegarde un conseil pour le retrouver plus tard"""
    saved = SavedAdvice(
        user_id=current_user.id,
        title=request.title,
        message=request.message,
    )
    db.add(saved)
    db.commit()
    db.refresh(saved)
    return saved


@router.get("/advice/saved", response_model=list[SavedAdviceResponse])
def list_saved_advice(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Liste des conseils sauvegardés"""
    return db.query(SavedAdvice).filter(
        SavedAdvice.user_id == current_user.id,
    ).order_by(SavedAdvice.created_at.desc()).all()


@router.put("/advice/saved/{advice_id}/rate", response_model=SavedAdviceResponse)
def rate_advice(
    advice_id: int,
    request: RateAdviceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Note la pertinence d'un conseil sauvegardé (1-5)"""
    if not 1 <= request.rating <= 5:
        raise HTTPException(status_code=400, detail="La note doit être entre 1 et 5")

    saved = db.query(SavedAdvice).filter(
        SavedAdvice.id == advice_id,
        SavedAdvice.user_id == current_user.id,
    ).first()
    if not saved:
        raise HTTPException(status_code=404, detail="Conseil non trouvé")

    saved.rating = request.rating
    db.commit()
    db.refresh(saved)
    return saved


@router.delete("/advice/saved/{advice_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_saved_advice(
    advice_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Supprime un conseil sauvegardé"""
    saved = db.query(SavedAdvice).filter(
        SavedAdvice.id == advice_id,
        SavedAdvice.user_id == current_user.id,
    ).first()
    if not saved:
        raise HTTPException(status_code=404, detail="Conseil non trouvé")

    db.delete(saved)
    db.commit()
    return None


@router.get("/chat/suggestions", response_model=list[str])
def get_chat_suggestions():
    """Suggestions de questions pour le chat"""
    return CHAT_SUGGESTIONS


@router.get("/chat/history", response_model=list[ChatMessageResponse])
def get_chat_history(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Historique des conversations avec l'IA"""
    last = db.query(ChatMessage.conversation_id).filter(
        ChatMessage.user_id == current_user.id,
    ).order_by(ChatMessage.created_at.desc()).first()
    if not last:
        return []

    messages = db.query(ChatMessage).filter(
        ChatMessage.user_id == current_user.id,
        ChatMessage.conversation_id == last.conversation_id,
    ).order_by(ChatMessage.created_at.asc()).limit(limit).all()
    return messages


@router.post("/chat", response_model=ChatResponse)
def chat(
    request: ChatRequest,
    conversation_id: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Questions libres à l'assistant IA (historique sauvegardé)"""
    conv_id = conversation_id or str(uuid.uuid4())
    reply = ai_service.chat(db, current_user.id, request.message)

    db.add(ChatMessage(
        user_id=current_user.id,
        conversation_id=conv_id,
        role="user",
        content=request.message,
    ))
    db.add(ChatMessage(
        user_id=current_user.id,
        conversation_id=conv_id,
        role="assistant",
        content=reply,
    ))
    db.commit()

    return ChatResponse(reply=reply, conversation_id=conv_id)


@router.post("/chat/voice", response_model=VoiceChatResponse)
async def chat_voice(
    file: UploadFile = File(...),
    conversation_id: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Chat vocal : transcrit l'audio puis répond (nécessite OPENAI_API_KEY)"""
    if not ai_service.has_openai:
        raise HTTPException(
            status_code=503,
            detail="Transcription vocale non disponible : configurez OPENAI_API_KEY"
        )

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Fichier audio vide")

    try:
        transcribed = ai_service.transcribe_audio(
            file.filename or "voice.mp3",
            content,
            file.content_type or "application/octet-stream",
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Erreur de transcription : {e}")

    conv_id = conversation_id or str(uuid.uuid4())
    reply = ai_service.chat(db, current_user.id, transcribed)

    db.add(ChatMessage(
        user_id=current_user.id,
        conversation_id=conv_id,
        role="user",
        content=transcribed,
    ))
    db.add(ChatMessage(
        user_id=current_user.id,
        conversation_id=conv_id,
        role="assistant",
        content=reply,
    ))
    db.commit()

    return VoiceChatResponse(transcribed=transcribed, reply=reply, conversation_id=conv_id)


@router.get("/monthly-report", response_model=MonthlyReportResponse)
def get_monthly_report(
    month: int | None = None,
    year: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Bilan mensuel généré par l'IA (génère si absent)"""
    now = datetime.utcnow()
    month = month or now.month
    year = year or now.year

    report = ai_service.generate_monthly_report(db, current_user.id, year, month)

    import json
    return MonthlyReportResponse(
        id=report.id,
        month=report.month,
        year=report.year,
        summary=report.summary,
        insights=json.loads(report.insights_json or "[]"),
        created_at=report.created_at,
    )


@router.get("/monthly-report/pdf")
def get_monthly_report_pdf(
    month: int | None = None,
    year: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Export PDF du bilan mensuel (partage)"""
    now = datetime.utcnow()
    month = month or now.month
    year = year or now.year

    report = ai_service.generate_monthly_report(db, current_user.id, year, month)

    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.units import mm
        from reportlab.platypus import Paragraph, SimpleDocTemplate
    except ImportError:
        raise HTTPException(status_code=503, detail="Module reportlab non installé")

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4,
                            leftMargin=20 * mm, rightMargin=20 * mm,
                            topMargin=20 * mm, bottomMargin=20 * mm)

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "TitleFR", parent=styles["Title"], fontName="Helvetica-Bold", fontSize=18,
    )
    body_style = ParagraphStyle(
        "BodyFR", parent=styles["BodyText"], fontName="Helvetica", fontSize=10.5, leading=15,
    )

    elements = [
        Paragraph(f"AFI - Bilan mensuel {month:02d}/{year}", title_style),
        Paragraph("<br/>", styles["BodyText"]),
    ]
    for line in report.summary.splitlines():
        if line.startswith("### "):
            elements.append(Paragraph(f"<b>{line.replace('### ', '')}</b>", title_style))
        else:
            elements.append(Paragraph(line, body_style))

    doc.build(elements)
    pdf = buffer.getvalue()

    return Response(
        content=pdf,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=afi-bilan-{year}-{month:02d}.pdf"},
    )