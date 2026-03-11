@echo off
echo Demarrage du serveur GPS Field Assist...
cd /d c:\1.0\backend
call venv\Scripts\activate.bat
echo.
echo Le serveur va demarrer sur http://0.0.0.0:8000
echo Utilisez l'IP locale du PC depuis le telephone
echo Appuyez sur CTRL+C pour arreter le serveur
echo.
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
pause

