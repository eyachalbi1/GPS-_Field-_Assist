@echo off
chcp 65001 >nul
echo ============================================================
echo Configuration pour test sur telephone reel
echo ============================================================
echo.

:: Obtenir l'IP locale
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
    set IP=%%a
    goto :found
)

:found
set IP=%IP:~1%

echo Votre adresse IP locale : %IP%
echo.
echo ============================================================
echo Configuration de l'application mobile
echo ============================================================
echo.
echo 1. Connectez votre telephone au meme WiFi que ce PC
echo 2. Dans l'application mobile, allez dans Parametres
echo 3. Entrez l'adresse IP : %IP%
echo 4. Entrez le port : 8000
echo 5. Sauvegardez
echo.
echo ============================================================
echo Test de connexion
echo ============================================================
echo.
echo Depuis le navigateur de votre telephone, ouvrez :
echo.
echo    http://%IP%:8000
echo.
echo Vous devriez voir : {"status":"ok","message":"..."}
echo.
echo ============================================================
echo Configuration du pare-feu
echo ============================================================
echo.
echo Si la connexion ne fonctionne pas, autorisez le port 8000 :
echo.
echo    netsh advfirewall firewall add rule name="GPS Field Assist" dir=in action=allow protocol=TCP localport=8000
echo.
echo Ou desactivez temporairement le pare-feu Windows
echo.
pause
