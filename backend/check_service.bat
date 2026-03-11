@echo off
echo ============================================================
echo Verification du service GPS Field Assist
echo ============================================================
echo.

sc query GPSFieldAssist

echo.
echo ============================================================
echo Pour gerer le service:
echo - Demarrer: net start GPSFieldAssist
echo - Arreter:  net stop GPSFieldAssist
echo - Statut:   sc query GPSFieldAssist
echo ============================================================
pause
