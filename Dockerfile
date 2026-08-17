# Stage 1: Builder
FROM python:3.11-slim@sha256:a630a63cdb314e2d138a2fca3e375e319e8568346ffafac5b980f888630ac4f1 AS builder

# OCR optionnel (EasyOCR/PyTorch ~2 Go) : docker build --build-arg INSTALL_OCR=true
# Ou via docker-compose : build.args.INSTALL_OCR=true
ARG INSTALL_OCR=false

WORKDIR /app

# Installer les dépendances système
# apt-get upgrade : applique les correctifs de sécurité des repos Debian au
# moment du build (le base image épinglé par digest vieillit sinon).
RUN apt-get update && apt-get upgrade -y --no-install-recommends && apt-get install -y --no-install-recommends \
    gcc=4:14.2.0-1 \
    libpq-dev=17.11-0+deb13u1 \
    && rm -rf /var/lib/apt/lists/*

# Installer les dépendances Python
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt && \
    pip install --user --no-cache-dir --upgrade setuptools==84.0.0 wheel==0.48.0

# Installer l'OCR si demandé (heavy)
COPY requirements-ocr.txt .
RUN if [ "$INSTALL_OCR" = "true" ]; then \
        pip install --user --no-cache-dir -r requirements-ocr.txt; \
    fi

# Stage 2: Runtime
FROM python:3.11-slim@sha256:a630a63cdb314e2d138a2fca3e375e319e8568346ffafac5b980f888630ac4f1

WORKDIR /app

# Installer libpq pour psycopg2
RUN apt-get update && apt-get upgrade -y --no-install-recommends && apt-get install -y --no-install-recommends \
    libpq5=17.11-0+deb13u1 \
    curl=8.14.1-2+deb13u4 \
    && rm -rf /var/lib/apt/lists/* && \
    pip install --no-cache-dir --upgrade setuptools==84.0.0 wheel==0.48.0

# Créer un utilisateur non-root (bonnes pratiques sécurité)
RUN groupadd --gid 10001 app && \
    useradd --uid 10001 --gid app --create-home --shell /usr/sbin/nologin app && \
    mkdir -p /app && chown app:app /app

# Copier les dépendances depuis le builder (site-packages système, accessible à tous les users)
COPY --from=builder /root/.local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /root/.local/bin /usr/local/bin

# Copier le code (propriétaire app)
COPY --chown=app:app ./app ./app

# Copier les migrations Alembic (exécutées par l'initContainer au déploiement)
COPY --chown=app:app alembic.ini .
COPY --chown=app:app ./alembic ./alembic

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
    CMD ["curl", "-f", "http://localhost:8000/health"]

# Bascule vers l'utilisateur non-root
USER app

# Commande de démarrage
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]