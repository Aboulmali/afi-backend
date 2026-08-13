# Stage 1: Builder
FROM python:3.11-slim AS builder

# OCR optionnel (EasyOCR/PyTorch ~2 Go) : docker build --build-arg INSTALL_OCR=true
# Ou via docker-compose : build.args.INSTALL_OCR=true
ARG INSTALL_OCR=false

WORKDIR /app

# Installer les dépendances système
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Installer les dépendances Python
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Installer l'OCR si demandé (heavy)
COPY requirements-ocr.txt .
RUN if [ "$INSTALL_OCR" = "true" ]; then \
        pip install --user --no-cache-dir -r requirements-ocr.txt; \
    fi

# Stage 2: Runtime
FROM python:3.11-slim

WORKDIR /app

# Installer libpq pour psycopg2
RUN apt-get update && apt-get install -y \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copier les dépendances depuis le builder
COPY --from=builder /root/.local /root/.local

# Copier le code
COPY ./app ./app

# Variables d'environnement
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
    CMD curl -f http://localhost:8000/health || exit 1

# Commande de démarrage
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]