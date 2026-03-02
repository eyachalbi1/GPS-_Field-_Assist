@echo off
cd /d "%~dp0"

echo ============================================================
echo Configuration du demarrage automatique
echo ============================================================
echo.

echo Creation d'une tache planifiee pour demarrer au demarrage...
echo.

# Creer une tache qui s'execute au demarrage de Windows
schtasks /create /tn "GPS Field Assist Server" /tr "\"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe\" -m uvicorn main:app --host 0.0.0.0 --port 8000" /sc onstart /ru System /f

echo.
echo ============================================================
echo Tache creee avec succes!
echo ============================================================
echo.
echo Le serveur demarrera automatiquement au demarrage de Windows.
echo.

# Verifier si la tache existe
schtasks /query /tn "GPS Field Assist Server"

echo.
pause
