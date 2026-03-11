@echo off
chcp 65001 >nul
echo ============================================================
echo 🔐 Configuration du Mot de Passe PostgreSQL
echo ============================================================
echo.

cd /d "%~dp0"

"c:\1.0\backend\venv\Scripts\python.exe" configure_password.py

echo.
pause
