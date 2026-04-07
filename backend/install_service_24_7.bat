@echo off
chcp 65001 >nul
echo ============================================================
echo Installation du service GPS Field Assist 24/7
echo ============================================================
cd /d "%~dp0"

:: Vérifier les droits administrateur
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERREUR: Ce script necessite les droits administrateur
    echo Faites un clic droit et selectionnez "Executer en tant qu'administrateur"
    pause
    exit /b 1
)

:: Arrêter et supprimer l'ancien service s'il existe
sc query GPSFieldAssist >nul 2>&1
if %errorlevel% equ 0 (
    echo Arret de l'ancien service...
    net stop GPSFieldAssist >nul 2>&1
    sc delete GPSFieldAssist >nul 2>&1
    timeout /t 2 >nul
)

:: Vérifier si NSSM existe
if not exist "nssm.exe" (
    echo Telechargement de NSSM...
    powershell -Command "Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile 'nssm.zip'"
    powershell -Command "Expand-Archive -Path 'nssm.zip' -DestinationPath '.' -Force"
    copy /Y "nssm-2.24\win64\nssm.exe" "nssm.exe"
    rmdir /s /q "nssm-2.24"
    del /f "nssm.zip"
)

echo.
echo Installation du service...

:: Installer le service
nssm install GPSFieldAssist "%CD%\venv\Scripts\python.exe"
nssm set GPSFieldAssist AppParameters "-m uvicorn main:app --host 0.0.0.0 --port 8000"
nssm set GPSFieldAssist AppDirectory "%CD%"
nssm set GPSFieldAssist Description "GPS Field Assist Backend Server - 24/7"
nssm set GPSFieldAssist DisplayName "GPS Field Assist"

:: Configuration du redémarrage automatique
nssm set GPSFieldAssist AppExit Default Restart
nssm set GPSFieldAssist AppRestartDelay 5000
nssm set GPSFieldAssist AppThrottle 10000

:: Démarrage automatique
nssm set GPSFieldAssist Start SERVICE_AUTO_START

:: Logs
nssm set GPSFieldAssist AppStdout "%CD%\logs\service_output.log"
nssm set GPSFieldAssist AppStderr "%CD%\logs\service_error.log"

:: Créer le dossier logs
if not exist "logs" mkdir logs

echo.
echo Demarrage du service...
net start GPSFieldAssist

echo.
echo ============================================================
echo Service installe et demarre avec succes!
echo ============================================================
echo.
echo Le serveur est maintenant accessible 24/7 sur:
echo   - http://localhost:8000
echo   - http://[VOTRE_IP]:8000
echo.
echo Le service redemarrera automatiquement en cas d'erreur
echo.
echo Commandes utiles:
echo   net stop GPSFieldAssist    - Arreter le service
echo   net start GPSFieldAssist   - Demarrer le service
echo   nssm edit GPSFieldAssist   - Modifier la configuration
echo   nssm remove GPSFieldAssist confirm - Desinstaller
echo.
pause
