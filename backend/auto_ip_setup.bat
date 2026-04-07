@echo off
chcp 65001 >nul
echo ============================================================
echo 🚀 AUTO IP SETUP ^& SERVER START - GPS Field Assist
echo ============================================================
echo.

REM Vérifier les droits administrateur pour netsh
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo AVERTISSEMENT: Droits admin non détectés. IP statique/fallback limités.
    set IS_ADMIN=0
) else (
    set IS_ADMIN=1
    echo ✅ Droits administrateur OK
)

REM Obtenir IP actuelle via commande demandée
echo Votre configuration IP actuelle:
ipconfig ^| findstr /C:"IPv4" /C:"Masque" /C:"Passerelle"
echo.

REM Extraire IPv4 pour affichage
set CURRENT_IP=
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4 Address" ^| findstr /V "0.0.0.0"') do (
    set CURRENT_IP=%%a
    set CURRENT_IP=!CURRENT_IP:~1!
    goto :ip_found
)
:ip_found
if not defined CURRENT_IP set CURRENT_IP=NON_DETECTE

echo.
echo IP détectée: %CURRENT_IP%
echo Serveur URL pour mobile: http://%CURRENT_IP%:8000
echo.

REM Option IP statique si admin
if "%IS_ADMIN%"=="1" (
    echo.
    set /p FIX_IP="Configurer IP fixe pour %CURRENT_IP%? (O/N): "
    if /i "%FIX_IP%"=="O" call :setup_static_ip
)

REM Configurer pare-feu
echo.
echo 🔒 Configuration pare-feu port 8000...
netsh advfirewall firewall delete rule name="GPS Field Assist Server" >nul 2>&1
netsh advfirewall firewall add rule name="GPS Field Assist Server" dir=in action=allow protocol=TCP localport=8000
echo ✅ Pare-feu OK

REM Démarrer serveur
echo.
echo 🌐 Démarrage serveur sur http://0.0.0.0:8000 ^(LAN: http://%CURRENT_IP%:8000^)
echo Test: Ouvrez http://%CURRENT_IP%:8000/health dans navigateur
echo Appuyez CTRL+C pour arrêter.
echo.
cd /d "%~dp0"
call venv\Scripts\activate.bat
uvicorn main:app --host 0.0.0.0 --port 8000 --reload

pause
exit /b

:setup_static_ip
echo.
echo Configuration IP statique pour %CURRENT_IP%...
REM Récupérer infos netsh
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"Subnet Mask"') do set SUBNET=%%a ^& set SUBNET=!SUBNET:~1!
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"Default Gateway"') do set GATEWAY=%%a ^& set GATEWAY=!GATEWAY:~1!

set /p CONFIRM="Utiliser: IP=%CURRENT_IP%, Masque=%SUBNET%, GW=%GATEWAY%? (O/N): "
if /i not "%CONFIRM%"=="O" exit /b

REM Trouver interface
for /f "tokens=* delims=:" %%i in ('ipconfig ^| findstr /C:"Ethernet adapter" /C:"Wireless" ^| findstr /V "Media"') do set IF_NAME=%%i

REM Netsh
netsh interface ip set address "%IF_NAME%" static %CURRENT_IP% %SUBNET% %GATEWAY%
netsh interface ip set dns "%IF_NAME%" static 8.8.8.8
netsh interface ip add dns "%IF_NAME%" 8.8.4.4 index=2
echo ✅ IP fixe configurée!
ipconfig ^| findstr "IPv4"
goto :eof

