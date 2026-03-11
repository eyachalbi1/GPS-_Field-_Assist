@echo off
color 0A
echo ========================================
echo   INSTALLATION SERVICE 24H/24
echo   GPS FIELD ASSIST
echo ========================================
echo.
echo Ce script va installer le serveur
echo comme service Windows.
echo.
echo Le service demarrera automatiquement
echo au demarrage du PC.
echo.
echo.
echo Appuyez sur une touche pour continuer...
pause >nul

echo.
echo [1] Installation du service...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0install_service.ps1"

echo.
echo [2] Demarrage du service...
net start GPSFieldAssist

echo.
echo ========================================
echo   SERVICE INSTALLE!
echo ========================================
echo.
echo Le service GPSFieldAssist est maintenant
echo actif et demarrera automatiquement
echo a chaque demarrage du PC.
echo.
echo Pour arreter le service:
echo   net stop GPSFieldAssist
echo.
echo Pour desinstaller le service:
echo   nssm remove GPSFieldAssist
echo.
pause

