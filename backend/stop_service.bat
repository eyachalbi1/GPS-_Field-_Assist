@echo off
cd /d "%~dp0"

echo ============================================================
echo Arret du service GPS Field Assist
echo ============================================================
echo.

net stop GPSFieldAssist

echo.
if %errorlevel% equ 0 (
    echo Service arrete avec succes!
) else (
    echo Erreur lors de l'arret du service
    echo.
    echo Essayez d'executer en tant qu'administrateur
    echo Clic droit sur ce fichier - Executer en tant qu'administrateur
)
echo.
pause
