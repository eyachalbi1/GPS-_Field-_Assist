@echo off
chcp 65001 >nul
echo ============================================================
echo 🔐 Configuration du Mot de Passe PostgreSQL
echo ============================================================
echo.

cd /d "%~dp0"

"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" configure_password.py

echo.
pause
