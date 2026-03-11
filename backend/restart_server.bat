@echo off
chcp 65001 >nul
echo ============================================================
echo Redemarrage du serveur GPS Field Assist
echo ============================================================
echo.

cd /d "%~dp0"

echo [1/3] Arret des processus existants...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000') do (
    taskkill /F /PID %%a >nul 2>&1
)
echo     [OK] Port 8000 libere
echo.

echo [2/3] Verification de la base de donnees...
sc query postgresql-x64-17 >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=3" %%a in ('sc query postgresql-x64-17 ^| findstr "STATE"') do set PGSTATE=%%a
    if "%PGSTATE%"=="RUNNING" (
        echo     [OK] PostgreSQL en cours d'execution
    ) else (
        echo     [ATTENTION] PostgreSQL arrete - Demarrage...
        net start postgresql-x64-17 >nul 2>&1
    )
) else (
    echo     [ATTENTION] PostgreSQL non installe
)
echo.

echo [3/3] Demarrage du serveur...
echo.
echo Le serveur va demarrer sur http://0.0.0.0:8000
echo Appuyez sur CTRL+C pour arreter
echo.
"c:\1.0\backend\venv\Scripts\python.exe" -m uvicorn main:app --host 0.0.0.0 --port 8000
