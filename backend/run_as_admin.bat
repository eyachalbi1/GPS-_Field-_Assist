@echo off
cd /d "%~dp0"

echo ============================================================
echo Installation du service GPS Field Assist
echo ============================================================
echo.

echo Installation du service...
nssm.exe install GPSFieldAssist "c:\1.0\backend\venv\Scripts\python.exe" "-m uvicorn main:app --host 0.0.0.0 --port 8000"

echo Configuration du repertoire...
nssm.exe set GPSFieldAssist AppDirectory "%CD%"

echo.
echo ============================================================
echo Demarrage du service...
echo ============================================================
net start GPSFieldAssist

echo.
echo ============================================================
echo Termine!
echo ============================================================
echo Le serveur est maintenant en cours d'execution.
echo Vous pouvez verifier avec: net start GPSFieldAssist
pause
