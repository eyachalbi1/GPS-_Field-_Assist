@echo off
echo ========================================
echo   DEMARRAGE DIAGNOSTIC COMPLET
echo ========================================
echo.

cd /d "%~dp0"

echo Lancement du test de connexion...
echo.

python test_server_status.py

echo.
echo ========================================
pause

