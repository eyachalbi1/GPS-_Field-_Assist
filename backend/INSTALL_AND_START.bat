@echo off
echo ============================================================
echo Installation et demarrage du service GPS Field Assist
echo ============================================================
echo.
echo Ce script va:
echo 1. Installer le service Windows
echo 2. Demarrer le service
echo 3. Configurer le demarrage automatique
echo.
pause

cd /d "%~dp0"

echo.
echo [1/3] Installation du service...
call setup_service.bat

echo.
echo [2/3] Demarrage du service...
call start_service.bat

echo.
echo [3/3] Configuration demarrage automatique...
call setup_auto_startup.bat

echo.
echo ============================================================
echo Installation terminee!
echo Le serveur fonctionne maintenant 24h/24
echo URL: http://192.168.2.115:8000
echo ============================================================
pause
