@echo off
echo ========================================
echo Test du Backend - Login
echo ========================================
echo.

cd /d "%~dp0"

echo Lancement des tests de login...
"C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" test_login.py

echo.
pause
