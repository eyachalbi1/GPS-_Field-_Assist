#!/usr/bin/env python3
"""
Service de métriques Prometheus pour GPS Field Assist
Expose des métriques personnalisées pour le monitoring
"""

import psutil
import time
from datetime import datetime
from prometheus_client import Counter, Gauge, Histogram, Summary, generate_latest, CONTENT_TYPE_LATEST
from fastapi import FastAPI, Response
from fastapi.responses import PlainTextResponse

app = FastAPI()

# Métriques personnalisées GPS Field Assist

# ——— Compteurs ———
TOTAL_REQUESTS = Counter(
    'gps_field_assist_requests_total',
    'Nombre total de requêtes HTTP',
    ['method', 'endpoint', 'status']
)

LOGIN_ATTEMPTS = Counter(
    'gps_field_assist_login_attempts_total',
    'Tentatives de connexion',
    ['status']  # success, failure
)

TASKS_CREATED = Counter(
    'gps_field_assist_tasks_created_total',
    'Nombre de tâches créées'
)

SMS_SENT = Counter(
    'gps_field_assist_sms_sent_total',
    'Nombre de SMS envoyés',
    ['status']  # success, failure
)

# ——— Gauges (valeurs instantanées) ———
ACTIVE_USERS = Gauge(
    'gps_field_assist_active_users',
    'Nombre d\'utilisateurs actifs (connectés dans les 24h)'
)

PENDING_TASKS = Gauge(
    'gps_field_assist_pending_tasks',
    'Nombre de tâches en attente'
)

IN_PROGRESS_TASKS = Gauge(
    'gps_field_assist_in_progress_tasks',
    'Nombre de tâches en cours'
)

DB_CONNECTIONS = Gauge(
    'gps_field_assist_db_connections',
    'Nombre de connexions à la base de données'
)

# ——— Histogrammes (distribution) ———
REQUEST_DURATION = Histogram(
    'gps_field_assist_request_duration_seconds',
    'Durée des requêtes HTTP',
    ['method', 'endpoint'],
    buckets=(0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0)
)

API_RESPONSE_TIME = Summary(
    'gps_field_assist_api_response_time_seconds',
    'Temps de réponse de l\'API',
    ['endpoint']
)

# ——— Métriques système (via psutil) ———
CPU_USAGE = Gauge(
    'gps_field_assist_cpu_usage_percent',
    'Utilisation CPU du processus'
)

MEMORY_USAGE = Gauge(
    'gps_field_assist_memory_usage_bytes',
    'Utilisation mémoire du processus'
)

DISK_USAGE = Gauge(
    'gps_field_assist_disk_usage_percent',
    'Utilisation disque du serveur'
)

# Initialisation
start_time = time.time()
process = psutil.Process()

@app.get("/metrics")
async def metrics():
    """Endpoint Prometheus /metrics"""
    # Mettre à jour les métriques système avant chaque scrape
    try:
        CPU_USAGE.set(psutil.cpu_percent(interval=0.1))
        MEMORY_USAGE.set(process.memory_info().rss)  # Resident Set Size
        DISK_USAGE.set(psutil.disk_usage('/').percent)
    except Exception as e:
        pass  # Ne pas faire échouer /metrics si psutil échoue

    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/health")
async def health():
    """Healthcheck étendu avec métriques"""
    return {
        "status": "healthy",
        "service": "GPS Field Assist",
        "timestamp": datetime.utcnow().isoformat(),
        "uptime_seconds": time.time() - start_time
    }

# ——— Fonctions helper à importer dans main.py ———

def track_request(method: str, endpoint: str, status: int, duration: float):
    """Tracker une requête HTTP"""
    TOTAL_REQUESTS.labels(method=method, endpoint=endpoint, status=status).inc()
    REQUEST_DURATION.labels(method=method, endpoint=endpoint).observe(duration)

def track_login(status: str):
    """Tracker une tentative de login"""
    LOGIN_ATTEMPTS.labels(status=status).inc()

def track_task_created():
    """Tracker création tâche"""
    TASKS_CREATED.inc()

def track_sms(status: str):
    """Tracker envoi SMS"""
    SMS_SENT.labels(status=status).inc()

def update_active_users_count(count: int):
    """Mettre à jour nombre utilisateurs actifs"""
    ACTIVE_USERS.set(count)

def update_pending_tasks_count(count: int):
    """Mettre à jour tâches en attente"""
    PENDING_TASKS.set(count)

def update_in_progress_tasks_count(count: int):
    """Mettre à jour tâches en cours"""
    IN_PROGRESS_TASKS.set(count)

def update_db_connections_count(count: int):
    """Mettre à jour connexions DB"""
    DB_CONNECTIONS.set(count)

# Exemple d'intégration dans FastAPI middleware:
"""
from fastapi import Request
import time

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    
    response = await call_next(request)
    
    duration = time.time() - start_time
    track_request(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code,
        duration=duration
    )
    
    return response
"""

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
