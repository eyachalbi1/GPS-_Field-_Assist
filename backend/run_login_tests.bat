@echo off
echo ========================================
echo Test du Backend - Login
echo ========================================
echo.

cd /d "%~dp0"

echo Lancement des tests de login...
"c:\1.0\backend\venv\Scripts\python.exe" test_login.py

echo.
pause
