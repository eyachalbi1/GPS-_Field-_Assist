@echo off
echo ========================================
echo CONFIGURATION IP FIXE - GPS FIELD ASSIST
echo ========================================
echo.

REM Vérifier les droits administrateur
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERREUR: Ce script necessite les droits administrateur
    echo Faites un clic droit et selectionnez "Executer en tant qu'administrateur"
    pause
    exit /b 1
)

echo Configuration actuelle:
echo.
ipconfig | findstr /C:"IPv4" /C:"Masque" /C:"Passerelle"
echo.
echo ========================================
echo.

set /p CONTINUE="Voulez-vous configurer une IP fixe? (O/N): "
if /i not "%CONTINUE%"=="O" (
    echo Operation annulee
    pause
    exit /b 0
)

echo.
echo Entrez les informations reseau:
echo.

set /p IP_ADDRESS="Adresse IP fixe (ex: 41.226.24.13): "
set /p SUBNET_MASK="Masque de sous-reseau (ex: 255.255.255.0): "
set /p GATEWAY="Passerelle par defaut (ex: 41.226.24.1): "
set /p DNS1="DNS primaire (ex: 8.8.8.8): "
set /p DNS2="DNS secondaire (ex: 8.8.4.4): "

echo.
echo Recherche de l'interface reseau active...

REM Trouver le nom de l'interface réseau active
for /f "tokens=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20 delims=:" %%a in ('ipconfig ^| findstr /C:"Ethernet" /C:"Wi-Fi"') do (
    set INTERFACE_NAME=%%a
    goto :found
)

:found
set INTERFACE_NAME=%INTERFACE_NAME:~1%
echo Interface trouvee: %INTERFACE_NAME%
echo.

echo Configuration de l'IP fixe...
netsh interface ip set address name="%INTERFACE_NAME%" static %IP_ADDRESS% %SUBNET_MASK% %GATEWAY%

echo Configuration du DNS...
netsh interface ip set dns name="%INTERFACE_NAME%" static %DNS1%
netsh interface ip add dns name="%INTERFACE_NAME%" %DNS2% index=2

echo.
echo ========================================
echo Configuration terminee!
echo ========================================
echo.
echo Nouvelle configuration:
ipconfig | findstr /C:"IPv4" /C:"Masque" /C:"Passerelle"
echo.

echo Configuration du pare-feu pour le port 8000...
netsh advfirewall firewall delete rule name="GPS Field Assist Server" >nul 2>&1
netsh advfirewall firewall add rule name="GPS Field Assist Server" dir=in action=allow protocol=TCP localport=8000

echo.
echo ========================================
echo IMPORTANT: Mettez a jour l'IP dans l'app mobile
echo Fichier: mobile\lib\services\gps_device_service.dart
echo Ligne: static const String apiUrl = 'http://%IP_ADDRESS%:8000/api/gps-devices';
echo ========================================
echo.

pause
