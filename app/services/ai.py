"""Service IA : insights, conseils et chat.

Utilise l'API OpenAI si OPENAI_API_KEY est configurée,
sinon bascule sur un moteur local à base de règles sur les vraies données.
"""
import json
from datetime import datetime, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.config import settings
from app.models.category import Category
from app.models.monthly_report import MonthlyReport
from app.models.transaction import Transaction, TransactionType

FRENCH_MONTHS = [
    "janvier", "février", "mars", "avril", "mai", "juin",
    "juillet", "août", "septembre", "octobre", "novembre", "décembre",
]

CHAT_SUGGESTIONS = [
    "Comment épargner davantage ?",
    "Où puis-je réduire mes dépenses ?",
    "Analyse mon mois dernier",
    "Quel est mon plus gros poste de dépense ?",
]


class AIService:
    def __init__(self):
        self._openai_client = None
        if settings.OPENAI_API_KEY:
            try:
                from openai import OpenAI
                self._openai_client = OpenAI(api_key=settings.OPENAI_API_KEY)
            except Exception:
                self._openai_client = None

    @property
    def has_openai(self) -> bool:
        return self._openai_client is not None

    def transcribe_audio(self, filename: str, content: bytes, content_type: str) -> str:
        """Transcrit un audio en texte via OpenAI Whisper"""
        if not self._openai_client:
            raise RuntimeError("OPENAI_API_KEY non configurée")
        response = self._openai_client.audio.transcriptions.create(
            model="whisper-1",
            file=(filename, content, content_type),
        )
        return response.text

    # ---------- Données ----------

    def _month_expenses(self, db: Session, user_id: int, months_ago: int = 0) -> float:
        now = datetime.utcnow()
        year, month = now.year, now.month - months_ago
        while month <= 0:
            month += 12
            year -= 1
        return db.query(func.sum(Transaction.amount)).filter(
            Transaction.user_id == user_id,
            Transaction.type == TransactionType.EXPENSE,
            func.extract('month', Transaction.transaction_date) == month,
            func.extract('year', Transaction.transaction_date) == year,
        ).scalar() or 0.0

    def _spending_by_category(self, db: Session, user_id: int) -> list[tuple]:
        now = datetime.utcnow()
        rows = db.query(
            Transaction.category_id,
            func.sum(Transaction.amount).label("total"),
        ).filter(
            Transaction.user_id == user_id,
            Transaction.type == TransactionType.EXPENSE,
            func.extract('month', Transaction.transaction_date) == now.month,
            func.extract('year', Transaction.transaction_date) == now.year,
        ).group_by(Transaction.category_id).order_by(func.sum(Transaction.amount).desc()).all()

        result = []
        for row in rows:
            cat = db.query(Category).filter(Category.id == row.category_id).first()
            result.append((cat.name if cat else "?", row.total or 0.0))
        return result

    def _category_name(self, db: Session, category_id: int | None) -> str:
        if category_id is None:
            return "?"
        cat = db.query(Category).filter(Category.id == category_id).first()
        return cat.name if cat else "?"

    # ---------- Insights ----------

    def generate_insights(self, db: Session, user_id: int) -> list[dict]:
        """Analyse automatique des habitudes financières du mois."""
        insights = []
        now = datetime.utcnow()
        current = self._month_expenses(db, user_id, 0)
        previous = self._month_expenses(db, user_id, 1)

        if current > 0:
            pct = (current - previous) / previous * 100 if previous else None
            if pct is not None and pct > 20:
                insights.append({
                    "title": "Dépenses en hausse",
                    "message": f"Vos dépenses de {now.strftime('%B')} ont augmenté de {pct:.0f}% par rapport au mois précédent.",
                    "severity": "danger",
                })
            elif pct is not None and pct < -20:
                insights.append({
                    "title": "Dépenses en baisse",
                    "message": f"Bravo ! Vos dépenses ont baissé de {abs(pct):.0f}% ce mois-ci.",
                    "severity": "success",
                })

        categories = self._spending_by_category(db, user_id)
        if categories:
            top_name, top_amount = categories[0]
            total = sum(a for _, a in categories)
            insights.append({
                "title": "Plus gros poste de dépense",
                "message": f"« {top_name} » est votre plus gros poste ce mois-ci : {top_amount:,.0f} F ({top_amount / total * 100:.0f}% des dépenses).",
                "severity": "info",
            })

        if len(categories) >= 2:
            second_name, second_amount = categories[1]
            insights.append({
                "title": "Piste d'économie",
                "message": f"En réduisant « {second_name} » ({second_amount:,.0f} F), vous pourriez économiser significativement.",
                "severity": "warning",
            })

        if not insights:
            insights.append({
                "title": "Aucune tendance détectée",
                "message": "Ajoutez quelques transactions pour recevoir des analyses personnalisées.",
                "severity": "info",
            })

        base = int(datetime.utcnow().timestamp())
        for i, ins in enumerate(insights):
            ins["id"] = base + i
            ins["date"] = datetime.utcnow()
        return insights

    # ---------- Conseils ----------

    def generate_advice(self, db: Session, user_id: int) -> list[dict]:
        """Conseils personnalisés basés sur les habitudes réelles."""
        advice = []
        current = self._month_expenses(db, user_id, 0)
        previous = self._month_expenses(db, user_id, 1)

        if previous and current > previous:
            advice.append({
                "title": "Contrôlez vos dépenses",
                "message": f"Vos dépenses sont en hausse de {(current - previous) / previous * 100:.0f}%. Fixez-vous un budget hebdomadaire pour inverser la tendance.",
            })

        categories = self._spending_by_category(db, user_id)
        for name, amount in categories[:2]:
            advice.append({
                "title": f"Réduisez « {name} »",
                "message": f"Vous avez dépensé {amount:,.0f} F dans « {name} » ce mois-ci. Essayez de définir un budget maximal pour cette catégorie.",
            })

        if not advice:
            advice.append({
                "title": "Construisez votre épargne",
                "message": "Conseil : mettez de côté 10% de vos revenus dès le début du mois, avant toute dépense.",
            })

        base = int(datetime.utcnow().timestamp())
        for i, a in enumerate(advice):
            a["id"] = base + i
            a["saved"] = False
        return advice

    # ---------- Chat ----------

    def chat(self, db: Session, user_id: int, message: str) -> str:
        """Répond à une question libre. OpenAI si configuré, sinon règles locales."""
        lower = message.lower()

        if self.has_openai:
            return self._chat_openai(db, user_id, message)

        # Fallback local par mots-clés sur les vraies données
        if "épargn" in lower or "epargn" in lower or "économis" in lower or "economis" in lower:
            current = self._month_expenses(db, user_id, 0)
            cats = self._spending_by_category(db, user_id)
            suggestion = cats[0][0] if cats else "vos dépenses"
            return (f"Pour épargner davantage : vos dépenses du mois s'élèvent à {current:,.0f} F. "
                    f"Le poste « {suggestion} » est votre plus gros. Réduisez-le de 20% et mettez la différence de côté.")

        if "réduire" in lower or "reduire" in lower or "dépense" in lower or "depense" in lower:
            cats = self._spending_by_category(db, user_id)
            if cats:
                name, amount = cats[0]
                return (f"Votre plus gros poste de dépense est « {name} » : {amount:,.0f} F ce mois-ci. "
                        "Fixez-lui un budget plafond, préférez le fait maison et comparez les prix.")
            return "Vous n'avez pas encore de dépenses ce mois-ci. Ajoutez-en pour obtenir des conseils."

        if "budget" in lower:
            cats = self._spending_by_category(db, user_id)
            if cats:
                lines = " | ".join(f"{n} : {a:,.0f} F" for n, a in cats[:3])
                return f"Votre répartition du mois : {lines}. Définissez un budget par catégorie pour mieux maîtriser."
            return "Définissez un budget mensuel dans l'onglet Profil pour mieux suivre vos dépenses."

        if "analyse" in lower or "analys" in lower or "bilan" in lower or "mois" in lower:
            current = self._month_expenses(db, user_id, 0)
            previous = self._month_expenses(db, user_id, 1)
            trend = f"en hausse de {(current - previous) / previous * 100:.0f}%" if previous and current > previous else "stable" if previous == 0 else f"en baisse de {(previous - current) / previous * 100:.0f}%"
            return (f"Ce mois-ci : {current:,.0f} F de dépenses ({trend} vs mois précédent). "
                    "Poursuivez vos suivis quotidiens pour un bilan plus précis.")

        return ("Je suis votre assistant AFI. Je peux vous aider sur : vos dépenses, "
                "vos budgets, l'épargne, et analyser vos finances. Essayez par exemple "
                "« Comment épargner davantage ? » ou « Où puis-je réduire mes dépenses ? »")

    def _chat_openai(self, db: Session, user_id: int, message: str) -> str:
        try:
            current = self._month_expenses(db, user_id, 0)
            cats = self._spending_by_category(db, user_id)
            context = (
                f"Utilisateur du mois : {current:,.0f} F de dépenses. "
                f"Répartition : {', '.join(f'{n} {a:,.0f}' for n, a in cats)}."
            )
            response = self._openai_client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system",
                     "content": "Tu es un assistant financier francophone concis. Utilise les données fournies."},
                    {"role": "user", "content": f"{context}\nQuestion : {message}"},
                ],
                max_tokens=250,
            )
            return response.choices[0].message.content or "Je n'ai pas de réponse."
        except Exception:
            return "Service IA momentanément indisponible. Réessayez dans un instant."

    # ---------- Bilan mensuel ----------

    def _month_summary(self, db: Session, user_id: int, year: int, month: int) -> tuple[str, list[str]]:
        """Construit le résumé du bilan mensuel + points forts/faibles"""
        start = datetime(year, month, 1)
        end = (start + timedelta(days=32)).replace(day=1)

        expenses = _sum_tx(db, user_id, TransactionType.EXPENSE, start, end)
        income = _sum_tx(db, user_id, TransactionType.INCOME, start, end)

        prev_start = (start - timedelta(days=1)).replace(day=1)
        prev_end = start
        prev_expenses = _sum_tx(db, user_id, TransactionType.EXPENSE, prev_start, prev_end)

        days = (end - start).days
        daily_avg = expenses / days if days and expenses else 0.0

        cats = self._spending_by_category_period(db, user_id, start, end)

        lines = [f"### Bilan de {FRENCH_MONTHS[month - 1]} {year}"]
        lines.append(f"- **Dépenses** : {expenses:,.0f} F")
        lines.append(f"- **Recettes** : {income:,.0f} F")
        lines.append(f"- **Solde** : {income - expenses:,.0f} F")
        lines.append(f"- **Moyenne journalière** : {daily_avg:,.0f} F")

        weaknesses = []
        strengths = []
        if prev_expenses and expenses > prev_expenses * 1.1:
            weaknesses.append(f"Les dépenses ont augmenté de {(expenses - prev_expenses) / prev_expenses * 100:.0f}% par rapport à {FRENCH_MONTHS[prev_start.month - 1]}.")
        elif prev_expenses and expenses < prev_expenses * 0.9:
            strengths.append(f"Bravo, les dépenses ont baissé de {(prev_expenses - expenses) / prev_expenses * 100:.0f}%.")

        if cats:
            top_name, top_amount = cats[0]
            weaknesses.append(f"« {top_name} » reste le plus gros poste : {top_amount:,.0f} F.")
            if len(cats) >= 2:
                second_name, second_amount = cats[1]
                strengths.append(f"Piste d'économie : réduire « {second_name} » ({second_amount:,.0f} F).")

        if income == 0:
            weaknesses.append("Aucune recette ce mois-ci : la dépendance aux dépenses est élevée.")
        else:
            savings_rate = (income - expenses) / income * 100
            if savings_rate > 0:
                strengths.append(f"Taux d'épargne de {savings_rate:.0f}% des recettes.")
            else:
                weaknesses.append("Le taux d'épargne est négatif : les dépenses dépassent les recettes.")

        if weaknesses:
            lines.append("\n### Points faibles")
            for w in weaknesses:
                lines.append(f"- {w}")
        if strengths:
            lines.append("\n### Points forts")
            for s in strengths:
                lines.append(f"- {s}")

        recommendations = []
        if cats:
            recommendations.append(f"Fixez un budget plafond à « {cats[0][0]} » pour le mois prochain.")
        if prev_expenses and expenses > prev_expenses:
            recommendations.append("Retrouvez le niveau de dépenses du mois précédent en réduisant les postes secondaires.")
        if income == 0:
            recommendations.append("Ajoutez vos revenus pour un bilan plus complet.")
        lines.append("\n### Recommandations pour le mois prochain")
        for r in recommendations or ["Continuez à saisir vos dépenses quotidiennement pour un suivi précis."]:
            lines.append(f"- {r}")

        insight_messages = [i["message"] for i in self._month_insights_for_period(db, user_id, start, end)]
        return "\n".join(lines), insight_messages

    def generate_monthly_report(self, db: Session, user_id: int, year: int, month: int) -> MonthlyReport:
        """Génère (ou renvoie) le bilan mensuel du mois demandé"""
        existing = db.query(MonthlyReport).filter(
            MonthlyReport.user_id == user_id,
            MonthlyReport.month == month,
            MonthlyReport.year == year,
        ).first()
        if existing:
            return existing

        summary, insights = self._month_summary(db, user_id, year, month)
        report = MonthlyReport(
            user_id=user_id,
            month=month,
            year=year,
            summary=summary,
            insights_json=json.dumps(insights, ensure_ascii=False),
        )
        db.add(report)
        db.commit()
        db.refresh(report)
        return report

    def _spending_by_category_period(self, db: Session, user_id: int, start: datetime, end: datetime) -> list[tuple]:
        rows = db.query(
            Transaction.category_id,
            func.sum(Transaction.amount).label("total"),
        ).filter(
            Transaction.user_id == user_id,
            Transaction.type == TransactionType.EXPENSE,
            Transaction.transaction_date >= start,
            Transaction.transaction_date < end,
        ).group_by(Transaction.category_id).order_by(func.sum(Transaction.amount).desc()).all()

        return [(self._category_name(db, r.category_id), r.total or 0.0) for r in rows]

    def _month_insights_for_period(self, db: Session, user_id: int, start: datetime, end: datetime) -> list[dict]:
        expenses = _sum_tx(db, user_id, TransactionType.EXPENSE, start, end)
        income = _sum_tx(db, user_id, TransactionType.INCOME, start, end)
        insights = []
        if expenses:
            insights.append({"message": f"Total des dépenses : {expenses:,.0f} F"})
        if income:
            insights.append({"message": f"Total des recettes : {income:,.0f} F"})
        cats = self._spending_by_category_period(db, user_id, start, end)
        if cats:
            insights.append({"message": f"Plus gros poste : « {cats[0][0]} » ({cats[0][1]:,.0f} F)"})
        return insights


def _sum_tx(db: Session, user_id: int, tx_type: TransactionType, start: datetime, end: datetime) -> float:
    """Somme des transactions entre deux dates"""
    return db.query(func.sum(Transaction.amount)).filter(
        Transaction.user_id == user_id,
        Transaction.type == tx_type,
        Transaction.transaction_date >= start,
        Transaction.transaction_date < end,
    ).scalar() or 0.0


ai_service = AIService()