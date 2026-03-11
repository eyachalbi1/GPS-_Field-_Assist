@echo off
chcp 65001 >nul
echo ============================================================
echo 📦 Installation de NSSM (Non-Sucking Service Manager)
echo ============================================================
cd /d "%~dp0"

:: Vérifier si NSSM existe déjà
if exist "nssm.exe" (
    echo NSSM deja present!
    goto :install_service
)

:: Télécharger NSSM
echo.
echo Telechargement de NSSM...
powershell -Command "Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile 'nssm.zip'"

:: Extraire NSSM
echo Extraction de NSSM...
powershell -Command "Expand-Archive -Path 'nssm.zip' -DestinationPath '.' -Force"

:: Copier nssm.exe
copy /Y "nssm-2.24\win64\nssm.exe" "nssm.exe"

:: Nettoyer
rmdir /s /q "nssm-2.24"
del /f "nssm.zip"

echo NSSM installe!

:install_service
echo.
echo ============================================================
echo 🔧 Installation du service GPS Field Assist
echo ============================================================
echo.

:: Installer le service avec uvicorn (gunicorn ne fonctionne pas sur Windows!)
nssm install GPSFieldAssist "c:\1.0\backend\venv\Scripts\python.exe" "-m uvicorn main:app --host 0.0.0.0 --port 8000"

:: Configurer le repertoire de travail
nssm set GPSFieldAssist AppDirectory "%CD%"

:: Description du service
nssm set GPSFieldAssist Description "GPS Field Assist Backend Server"

echo.
echo ============================================================
echo ✅ Service installe!
echo ============================================================
echo.
echo Pour demarrer le service:
echo   net start GPSFieldAssist
echo.
echo Pour arreter le service:
echo   net stop GPSFieldAssist
echo.
echo Pour desinstaller:
echo   nssm remove GPSFieldAssist confirm
echo.
pause
