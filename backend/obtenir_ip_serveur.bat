@echo off
echo ========================================
echo ADRESSE IP ACTUELLE DU SERVEUR
echo ========================================
echo.

for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4"') do (
    set IP=%%a
    set IP=!IP:~1!
    echo IP du serveur: !IP!
    echo.
    echo URL pour l'app mobile:
    echo http://!IP!:8000/api/gps-devices
    echo.
    goto :end
)

:end
echo ========================================
echo.
echo Pour fixer cette IP de maniere permanente:
echo 1. Executer "configurer_ip_fixe.bat" en tant qu'administrateur
echo 2. Ou configurer la reservation DHCP sur votre routeur
echo.
pause
