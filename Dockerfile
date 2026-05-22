FROM python:3.11-slim

WORKDIR /app

# Dépendances système
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc \
    && rm -rf /var/lib/apt/lists/*

# Backend
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .

# Assets statiques (PDFs, modules)
COPY mobile/assets/ ./static/assets/
COPY mobile/pdfs_modules/ ./static/pdf_cache/

# Dossiers nécessaires
RUN mkdir -p static/uploads static/modules

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
