@echo off
chcp 65001 >nul
cls
echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║                                                            ║
echo ║      CONFIGURATION AUTOMATIQUE - GPS FIELD ASSIST       ║
echo ║                                                            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo Ce script va configurer automatiquement tout le backend.
echo.
echo Vous aurez juste à entrer votre mot de passe PostgreSQL.
echo.
pause
echo.

cd /d "%~dp0"

echo ════════════════════════════════════════════════════════════
echo Étape 1/3: Configuration du mot de passe PostgreSQL
echo ════════════════════════════════════════════════════════════
echo.
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" configure_password.py
if errorlevel 1 (
    echo.
    echo  Erreur lors de la configuration du mot de passe
    echo.
    pause
    exit /b 1
)

echo.
echo ════════════════════════════════════════════════════════════
echo Étape 2/3: Configuration de la base de données
echo ════════════════════════════════════════════════════════════
echo.
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" setup_db.py
if errorlevel 1 (
    echo.
    echo  Erreur lors de la configuration de la base
    echo.
    pause
    exit /b 1
)

echo.
echo ════════════════════════════════════════════════════════════
echo Étape 3/3: Création de l'utilisateur de test
echo ════════════════════════════════════════════════════════════
echo.
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" create_test_user.py
if errorlevel 1 (
    echo.
    echo  Erreur lors de la création de l'utilisateur
    echo.
    pause
    exit /b 1
)

echo.
echo ════════════════════════════════════════════════════════════
echo  CONFIGURATION TERMINÉE AVEC SUCCÈS!
echo ════════════════════════════════════════════════════════════
echo.
echo  Identifiants de test créés:
echo    Username: tech1
echo    Password: password123
echo.
echo  Prochaines étapes:
echo    1. Démarrer le serveur:
echo       "C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" -m uvicorn main:app --reload --port 8000
echo.
echo    2. Tester le login (dans un autre terminal):
echo       "C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" test_login.py
echo.
echo  Ou utilisez start_here.bat pour un menu interactif
echo.
echo ════════════════════════════════════════════════════════════
echo.
pause
