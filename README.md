# AFI - Backend FastAPI

API REST pour **AFI - Assistant Financier Intelligent**, le backend du projet SamaPoche Scrum.

## Stack

- FastAPI + Uvicorn
- SQLAlchemy + PostgreSQL
- Auth JWT (bcrypt)
- Docker + docker-compose
- Pytest

## Lancer (Docker)

```bash
docker-compose up -d
```

## Lancer (local)

```bash
python -m venv venv
venv\Scripts\activate        # Windows
source venv/bin/activate     # Linux/Mac
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Documentation

- Swagger UI : http://localhost:8000/docs
- Health check : http://localhost:8000/health

## Tests

```bash
# Unitaires (SQLite, rapides)
pytest tests/unit -v

# Intégration + e2e (PostgreSQL réel)
docker exec afi-postgres psql -U afi -d afi_db -c "CREATE DATABASE afi_test;"
$env:AFI_TEST_POSTGRES="1"; $env:DATABASE_URL="postgresql://afi:password@localhost:5432/afi_test"
pytest tests/integration tests/e2e -v
```

## Pipeline CI/CD (GitHub Actions)

| Étape | Où | Détail |
|---|---|---|
| Branches | `BRANCHING.md` | GitFlow adapté : main/develop/feature/*/hotfix/* + template PR |
| Build & push image | `.github/workflows/cd.yml` | **Amazon ECR** `481665100214.dkr.ecr.eu-west-3.amazonaws.com/afi-backend` (tags sha/latest) |
| Tests unitaires | `ci.yml` | SQLite, 42 tests |
| Tests IHM | `ci.yml` | Flutter `analyze` + tests widget (`mobile/`) |
| Tests intégration/e2e | `ci.yml` | PostgreSQL 15 réel (service GitHub Actions), 5 tests |
| SAST | `ci.yml` | `ruff` + `bandit` + `hadolint` (Dockerfile) |
| Scan image | `ci.yml` | `Trivy` (HIGH/CRITICAL bloquant) |
| DAST | `ci.yml` | OWASP ZAP baseline scan sur l'API lancée |
| Qualimétrie | `cd.yml` | SonarCloud (secret `SONAR_TOKEN`) + **quality gate bloquante** |
| Provisionnement | `terraform/` | AWS : VPC + EKS + RDS PostgreSQL + S3 + ECR (`terraform validate` ✅) |
| Déploiement K8S | `cd.yml` | Helm vers **EKS** (`afi`, ns `afi-prod`) + rollback automatique si échec |
| Observabilité | `docker-compose.observability.yml` / `k8s/overlays/observability` | Prometheus + Grafana (+ Loki + Alertmanager), `/metrics` sur l'API |

### Secrets GitHub requis

| Secret | Usage |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | ECR, EKS, Terraform |
| `SONAR_TOKEN` / `SONAR_HOST_URL` | SonarCloud |
| `RDS_DATABASE_URL` | Base prod (secret K8s `afi-secrets`) |
| `OPENAI_API_KEY`, `SMTP_*` | Secrets K8s |

### Lancer l'observabilité (local)

```bash
docker compose -f docker-compose.observability.yml up -d
# Prometheus : http://localhost:9090  |  Grafana : http://localhost:3000 (admin/admin)
# Métriques API : http://localhost:8000/metrics
```

## Endpoints

| Méthode | URL | Description |
|---|---|---|
| POST | /api/v1/auth/register | Inscription |
| POST | /api/v1/auth/login | Connexion |
| GET | /api/v1/auth/me | Profil |
| POST | /api/v1/auth/forgot-password | Mot de passe oublié (token 2h) |
| POST | /api/v1/auth/reset-password | Réinitialiser le mot de passe |
| POST | /api/v1/transactions | Créer une transaction |
| GET | /api/v1/transactions | Lister (filtres : type, catégorie, dates, recherche) |
| PUT | /api/v1/transactions/{id} | Modifier |
| DELETE | /api/v1/transactions/{id} | Supprimer |
| GET | /api/v1/categories | Catégories |
| GET | /api/v1/dashboard/balance | Solde et stats |
| GET | /api/v1/dashboard/stats | Stats du mois + comparaison mois précédent |
| GET | /api/v1/dashboard/spending | Dépenses par catégorie (week/month/year) |
| GET | /api/v1/dashboard/evolution | Évolution mensuelle (6 mois) |
| POST | /api/v1/budgets | Définir un budget |
| GET | /api/v1/budgets | Budgets + alertes 80%/100% |
| PUT/DELETE | /api/v1/budgets/{id} | Modifier / Supprimer |
| GET | /api/v1/ai/insights | Insights automatiques IA |
| GET | /api/v1/ai/advice | Conseils personnalisés IA |
| POST | /api/v1/ai/chat | Chat avec l'assistant (historique sauvegardé) |
| POST | /api/v1/ai/advice/save | Sauvegarder un conseil |
| GET | /api/v1/ai/advice/saved | Conseils sauvegardés |
| PUT | /api/v1/ai/advice/saved/{id}/rate | Noter un conseil (1-5) |
| GET | /api/v1/ai/chat/history | Historique des conversations |
| GET | /api/v1/ai/chat/suggestions | Suggestions de questions |
| GET | /api/v1/ai/monthly-report | Bilan mensuel IA |
| GET | /api/v1/ai/monthly-report/pdf | Export PDF du bilan |
| GET | /api/v1/notifications | Notifications (all/unread/read) |
| PUT | /api/v1/notifications/{id}/read | Marquer comme lue |
| PUT | /api/v1/notifications/read-all | Tout marquer comme lu |
| GET/PUT | /api/v1/notifications/settings | Réglages rappel 20h |
| GET | /api/v1/notifications/reminders/due | Rappel du jour (logique anti-doublon) |
| POST | /api/v1/scan | Scan facture (OCR) |
| POST | /api/v1/scan/{id}/confirm | Valider le scan → transaction |
| POST | /api/v1/import/sms/parse | Analyser les SMS bancaires |
| POST | /api/v1/import/sms/confirm | Créer les transactions validées |
| GET | /api/v1/budgets/alerts | Historique des alertes budget |

L'IA utilise OpenAI si `OPENAI_API_KEY` est remplie, sinon un moteur local basé sur les vraies données (les tests passent sans clé).

Le planificateur (au démarrage) crée les rappels à l'heure configurée et génère les bilans mensuels le 1er du mois.

OCR pour le scan de factures : `pip install -r requirements-ocr.txt` (easyocr+opencv, ~2 Go avec PyTorch). Sans ça, `/api/v1/scan` répond 503 avec un message clair.