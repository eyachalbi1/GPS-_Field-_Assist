@echo off
echo Demarrage du serveur GPS Field Assist...
cd /d "%~dp0"

:: Chercher Python
set PYTHON=
where python >nul 2>&1 && set PYTHON=python
if "%PYTHON%"=="" where python3 >nul 2>&1 && set PYTHON=python3
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" set PYTHON=%LOCALAPPDATA%\Programs\Python\Python311\python.exe
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python310\python.exe" set PYTHON=%LOCALAPPDATA%\Programs\Python\Python310\python.exe
if "%PYTHON%"=="" if exist "C:\Python312\python.exe" set PYTHON=C:\Python312\python.exe
if "%PYTHON%"=="" if exist "C:\Python311\python.exe" set PYTHON=C:\Python311\python.exe
if "%PYTHON%"=="" if exist "C:\Python310\python.exe" set PYTHON=C:\Python310\python.exe

if "%PYTHON%"=="" (
    echo ERREUR: Python introuvable.
    echo Installez Python depuis https://www.python.org/downloads/
    echo Cochez "Add Python to PATH" lors de l'installation.
    pause
    exit /b 1
)

echo Python trouve : %PYTHON%
echo.
echo Le serveur va demarrer sur http://0.0.0.0:8000
echo Utilisez l'IP locale du PC depuis le telephone (ex: http://192.168.43.90:8000)
echo Appuyez sur CTRL+C pour arreter le serveur
echo.
"%PYTHON%" -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
pause
