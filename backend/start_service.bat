@echo off
cd /d "%~dp0"

echo ============================================================
echo Starting GPS Field Assist Service
echo ============================================================
echo.

sc query GPSFieldAssist >nul 2>&1
if %errorlevel% neq 0 (
    echo Service not installed!
    echo Please run setup_service.bat first
    pause
    exit /b 1
)

net start GPSFieldAssist

echo.
if %errorlevel% equ 0 (
    echo Service started successfully!
    echo Server available at http://localhost:8000
) else (
    echo Error starting service
    echo.
    echo Try running as administrator
    echo Right click on this file - Run as administrator
)
echo.
pause
