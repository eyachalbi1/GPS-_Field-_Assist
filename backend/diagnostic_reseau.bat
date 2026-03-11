@echo off
echo ========================================
echo   DIAGNOSTIC RESEAU - GPS FIELD ASSIST
echo ========================================
echo.

echo [1] Vérification de l'adresse IP locale...
echo ---------------------------------------------
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set "ip=%%a"
    echo IP détectée: !ip:~1!
)
echo.

echo [2] Vérification si le port 8000 est utilisé...
echo ---------------------------------------------
netstat -ano | findstr :8000
if %errorlevel% neq 0 (
    echo Le port 8000 n'est pas utilisé
) else (
    echo Le port 8000 est utilisé
)
echo.

echo [3] Test de connexion locale...
echo ---------------------------------------------
curl -s -o nul -w "%%{http_code}" http://localhost:8000/
if %errorlevel% equ 0 (
    echo Serveur local accessible!
) else (
    echo Serveur local NON accessible
)
echo.

echo [4] Instructions pour le mobile:
echo ---------------------------------------------
echo 1. Notez votre adresse IP: above
echo 2. Assurez-vous que le mobile est sur le meme WiFi
echo 3. Dans l'application: Diagnostique ^> Configuration Serveur
echo 4. Entrez l'IP notée ci-dessus
echo.
echo ========================================
pause

