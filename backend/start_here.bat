@echo off
chcp 65001 >nul
echo ============================================================
echo 🚀 GPS Field Assist - Configuration et Test Backend
echo ============================================================
echo.

cd /d "%~dp0"

:menu
echo.
echo Que voulez-vous faire?
echo.
echo 0. Configurer le mot de passe PostgreSQL (COMMENCEZ ICI)
echo 1. Configurer PostgreSQL et créer la base de données
echo 2. Créer un utilisateur technicien de test (tech1)
echo 3. Démarrer le serveur backend
echo 4. Tester le login (dans un autre terminal)
echo 5. Tout faire automatiquement (0+1+2)
echo 6. Quitter
echo.
set /p choice="Votre choix (0-6): "

if "%choice%"=="0" goto configure_password
if "%choice%"=="1" goto setup_db
if "%choice%"=="2" goto create_user
if "%choice%"=="3" goto start_server
if "%choice%"=="4" goto test_login
if "%choice%"=="5" goto auto_setup
if "%choice%"=="6" goto end
goto menu

:setup_db
echo.
echo ============================================================
echo 📊 Configuration de la base de données...
echo ============================================================
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" setup_db.py
pause
goto menu

:create_user
echo.
echo ============================================================
echo 👤 Création de l'utilisateur de test...
echo ============================================================
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" create_test_user.py
goto menu

:start_server
echo.
echo ============================================================
echo 🌐 Démarrage du serveur backend...
echo ============================================================
echo.
echo Le serveur va démarrer sur http://0.0.0.0:8000
echo Utilisez l'IP locale du PC depuis le téléphone (ex: http://192.168.x.x:8000)
echo Appuyez sur CTRL+C pour arrêter le serveur
echo.
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
goto menu

:test_login
echo.
echo ============================================================
echo 🧪 Test du login...
echo ============================================================
echo.
echo Assurez-vous que le serveur est démarré dans un autre terminal!
echo.
pause
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" test_login.py
pause
goto menu

:configure_password
echo.
echo ============================================================
echo 🔐 Configuration du mot de passe PostgreSQL...
echo ============================================================
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" configure_password.py
pause
goto menu

:auto_setup
echo.
echo ============================================================
echo ⚡ Configuration automatique...
echo ============================================================
echo.
echo Étape 1/3: Configuration du mot de passe...
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" configure_password.py
echo.
echo Étape 2/3: Configuration de la base de données...
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" setup_db.py
echo.
echo Étape 3/3: Création de l'utilisateur de test...
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" create_test_user.py
echo.
echo ============================================================
echo ✅ Configuration terminée!
echo ============================================================
echo.
echo Prochaines étapes:
echo 1. Démarrez le serveur (option 3)
echo 2. Dans un autre terminal, testez le login (option 4)
echo.
pause
goto menu

:end
echo.
echo Au revoir! 👋
echo.
exit
