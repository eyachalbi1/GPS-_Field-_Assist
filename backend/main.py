# main.py
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from src.routes.auth import router as auth_router
from src.routes.files import router as files_router
from src.routes.tasks import router as tasks_router
from src.models.database import init_users_table

app = FastAPI(title="GPS Field Assist")

# Configuration CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialiser les tables
init_users_table()

# Endpoint de santé pour vérifier que le serveur fonctionne
@app.get("/")
async def root():
    return {"status": "ok", "message": "GPS Field Assist Server is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "GPS Field Assist"}

# Routes d'authentification
app.include_router(auth_router, prefix="/api/auth", tags=["Auth"])

# Routes fichiers (upload / liste)
app.include_router(files_router, prefix="/api/files", tags=["Files"])

# Routes tâches
app.include_router(tasks_router, prefix="/api/tasks", tags=["Tasks"])

# Servir les fichiers statiques (PDFs, images uploaded)
app.mount("/static", StaticFiles(directory="static"), name="static")
app.mount("/uploads", StaticFiles(directory=os.path.join("static", "uploads")), name="uploads")
app.mount("/modules", StaticFiles(directory=os.path.join("static", "modules")), name="modules")
