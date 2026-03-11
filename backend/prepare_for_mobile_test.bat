@echo off
chcp 65001 >nul
cls
echo ============================================================
echo PREPARATION POUR TEST SUR TELEPHONE REEL
echo ============================================================
echo.

:: Vérifier les droits administrateur
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ATTENTION: Droits administrateur requis pour configurer le pare-feu
    echo Certaines etapes seront ignorees
    echo.
    set ADMIN=0
) else (
    set ADMIN=1
)

cd /d "%~dp0"

echo [1/5] Obtention de l'adresse IP...
echo.
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
    set IP=%%a
    goto :found_ip
)

:found_ip
set IP=%IP:~1%
echo     IP du PC : %IP%
echo.

if %ADMIN%==1 (
    echo [2/5] Configuration du pare-feu...
    netsh advfirewall firewall delete rule name="GPS Field Assist" >nul 2>&1
    netsh advfirewall firewall add rule name="GPS Field Assist" dir=in action=allow protocol=TCP localport=8000 profile=private,domain >nul 2>&1
    echo     [OK] Port 8000 autorise
    echo.
) else (
    echo [2/5] Configuration du pare-feu... [IGNORE - Pas admin]
    echo.
)

echo [3/5] Verification du service...
sc query GPSFieldAssist >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=3" %%a in ('sc query GPSFieldAssist ^| findstr "STATE"') do set STATE=%%a
    if "%STATE%"=="RUNNING" (
        echo     [OK] Service en cours d'execution
    ) else (
        echo     [ATTENTION] Service arrete - Demarrage...
        net start GPSFieldAssist >nul 2>&1
        if %errorlevel% equ 0 (
            echo     [OK] Service demarre
        ) else (
            echo     [ERREUR] Impossible de demarrer le service
            echo     Executez manuellement : net start GPSFieldAssist
        )
    )
) else (
    echo     [ATTENTION] Service non installe
    echo     Executez install_service_24_7.bat en tant qu'administrateur
)
echo.

echo [4/5] Test de connexion locale...
powershell -Command "try { $null = Invoke-WebRequest -Uri 'http://localhost:8000/health' -TimeoutSec 3 -UseBasicParsing; Write-Host '    [OK] Serveur repond correctement' -ForegroundColor Green } catch { Write-Host '    [ERREUR] Serveur ne repond pas' -ForegroundColor Red }" 2>nul
echo.

echo [5/5] Generation du QR Code de configuration...
echo     URL : http://%IP%:8000
echo.

echo ============================================================
echo CONFIGURATION TERMINEE
echo ============================================================
echo.
echo ETAPES SUIVANTES :
echo.
echo 1. Connectez votre telephone au meme WiFi que ce PC
echo.
echo 2. Dans l'application mobile :
echo    - Allez dans Parametres (icone engrenage)
echo    - IP du serveur : %IP%
echo    - Port : 8000
echo    - Sauvegardez
echo.
echo 3. Testez la connexion :
echo    - Ouvrez le navigateur du telephone
echo    - Allez sur : http://%IP%:8000
echo    - Vous devriez voir : {"status":"ok",...}
echo.
echo 4. Connectez-vous a l'application :
echo    - Username : technicien1
echo    - Password : tech2024
echo.
echo ============================================================
echo URLS DE TEST
echo ============================================================
echo.
echo Health check : http://%IP%:8000/health
echo API docs     : http://%IP%:8000/docs
echo.
echo ============================================================
echo.
pause
