@echo off
cd /d "%~dp0"

echo.
echo ========================================
echo CONFIGURATION BACKEND
echo ========================================
echo.
echo Etape 1: Configuration mot de passe
echo.
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" configure_password.py
echo.

echo Etape 2: Configuration base de donnees
echo.
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" setup_db.py
echo.

echo Etape 3: Creation utilisateur test
echo.
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" create_test_user.py
echo.

echo ========================================
echo CONFIGURATION TERMINEE!
echo ========================================
echo.
echo Identifiants: tech1 / password123
echo.
echo Pour demarrer le serveur:
echo "C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" -m uvicorn main:app --reload --port 8000
echo.
pause
