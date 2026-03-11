@echo off
chcp 65001 >nul
echo ============================================================
echo Verification du serveur GPS Field Assist
echo ============================================================
echo.

:: Vérifier si le service existe
sc query GPSFieldAssist >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERREUR] Service non installe
    echo Executez install_service_24_7.bat en tant qu'administrateur
    pause
    exit /b 1
)

:: Vérifier l'état du service
for /f "tokens=3" %%a in ('sc query GPSFieldAssist ^| findstr "STATE"') do set STATE=%%a

if "%STATE%"=="RUNNING" (
    echo [OK] Service en cours d'execution
    
    :: Tester la connexion HTTP
    echo.
    echo Test de connexion HTTP...
    powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:8000/api/auth/test' -TimeoutSec 5 -UseBasicParsing; Write-Host '[OK] Serveur repond correctement' -ForegroundColor Green } catch { Write-Host '[ATTENTION] Serveur ne repond pas' -ForegroundColor Yellow }"
) else (
    echo [ATTENTION] Service arrete - Redemarrage...
    net start GPSFieldAssist
    if %errorlevel% equ 0 (
        echo [OK] Service redemarre avec succes
    ) else (
        echo [ERREUR] Impossible de demarrer le service
    )
)

echo.
echo ============================================================
echo Logs du service:
echo ============================================================
if exist "logs\service_error.log" (
    echo Dernieres erreurs:
    powershell -Command "Get-Content 'logs\service_error.log' -Tail 10 -ErrorAction SilentlyContinue"
)

echo.
pause
