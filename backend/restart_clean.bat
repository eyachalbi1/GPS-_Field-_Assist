@echo off
echo Nettoyage du port 8000...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do (
    echo Arret du processus %%a
    taskkill /F /PID %%a 2>nul
)
timeout /t 2 /nobreak > nul
echo.
echo Demarrage du serveur...
"c:\1.0\backend\venv\Scripts\python.exe" -m uvicorn main:app --host 0.0.0.0 --port 8000
