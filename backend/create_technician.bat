@echo off
chcp 65001 >nul
echo ============================================================
echo Creation d'un compte technicien pour les tests
echo ============================================================
echo.

cd /d "%~dp0"

"c:\1.0\backend\venv\Scripts\python.exe" create_technician.py

echo.
echo ============================================================
echo Configuration terminee
echo ============================================================
echo.
echo Vous pouvez maintenant vous connecter avec ces identifiants
echo dans l'application mobile
echo.
pause
