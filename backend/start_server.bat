@echo off
echo Demarrage du serveur GPS Field Assist...
cd /d "%~dp0"
echo.
echo Le serveur va demarrer sur http://0.0.0.0:8000
echo Utilisez l'IP locale du PC depuis le telephone (ex: http://192.168.x.x:8000)
echo Appuyez sur CTRL+C pour arreter le serveur
echo.
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
pause
