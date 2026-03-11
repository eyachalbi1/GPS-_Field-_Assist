@echo off
setlocal enabledelayedexpansion
color 0A
echo.
echo ======================================================
echo   CONFIGURATION RAPIDE - GPS FIELD ASSIST
echo ======================================================
echo.

REM Etape 1: Detecter l'IP
echo [ETAPE 1] Detection de l'adresse IP locale...
echo ------------------------------------------------------
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set "ip=%%a"
    set "ip=!ip:~1!"
)
if defined ip (
    echo Votre adresse IP: !ip!
) else (
    set "ip=192.168.1.x"
    echo IP non detectee, utilisez: !ip!
)
echo.

REM Etape 2: Verifier si le serveur est en cours
echo [ETAPE 2] Verification du serveur...
echo ------------------------------------------------------
curl -s -o nul -w "%%{http_code}" http://localhost:8000/ 2>nul
if %errorlevel% equ 0 (
    echo Le serveur semble demarre sur localhost:8000
) else (
    echo Le serveur ne semble pas demarre.
    echo.
    echo Voulez-vous demarrer le serveur maintenant? (O/N)
    set /p choice="> "
    if /i "!choice!"=="O" (
        start "Serveur GPS" cmd /k "cd /d "%~dp0" && python -m uvicorn main:app --host 0.0.0.0 --port 8000"
        timeout /t 5 /nobreak >nul
    )
)
echo.

REM Etape 3: Configurer le pare-feu
echo [ETAPE 3] Configuration du pare-feu...
echo ------------------------------------------------------
echo Execution de configure_firewall.bat...
call configure_firewall.bat
echo.

REM Etape 4: Test de connexion
echo [ETAPE 4] Test de connexion...
echo ------------------------------------------------------
curl -s -X POST http://localhost:8000/api/auth/login -H "Content-Type: application/json" -d "{\"username\":\"admin\",\"password\":\"admin123\"}" 2>nul | findstr "token" >nul
if %errorlevel% equ 0 (
    echo Le serveur fonctionne et accepte les connexions!
) else (
    echo Le serveur repond mais les identifiants peuvent avoir un probleme.
)
echo.

REM Resume
echo ======================================================
echo   RECAPITULATIF
echo ======================================================
echo.
echo 1. Votre IP: !ip!
echo 2. Port: 8000
echo.
echo SUR LE MOBILE:
echo - Allez dans: Diagnostique ^> Configuration Serveur
echo - Entrez l'IP: !ip!
echo - Port: 8000
echo - Sauvegardez
echo.
echo - Identifiants:
echo   * Admin: admin / admin123
echo   * Tech: tech1 / tech123
echo.
echo ======================================================
echo.
pause

