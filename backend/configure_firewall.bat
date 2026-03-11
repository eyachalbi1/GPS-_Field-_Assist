@echo off
echo ========================================
echo   CONFIGURATION PAREFEU - GPS FIELD ASSIST
echo ========================================
echo.

echo Autorisation de Python dans le pare-feu...
echo.

REM Trouver Python et autoriser tous les fichiers python.exe
echo Recherche de Python...

REM Python 3.13
if exist "C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" (
    echo Trouve: Python 3.13
    netsh advfirewall firewall add rule name="GPS Field Assist - Python 313" dir=in action=allow program="C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe" enable=yes
)

REM Python 3.12
if exist "C:\Users\Asus\AppData\Local\Programs\Python\Python312\python.exe" (
    echo Trouve: Python 3.12
    netsh advfirewall firewall add rule name="GPS Field Assist - Python 312" dir=in action=allow program="C:\Users\Asus\AppData\Local\Programs\Python\Python312\python.exe" enable=yes
)

REM Python 3.11
if exist "C:\Users\Asus\AppData\Local\Programs\Python\Python311\python.exe" (
    echo Trouve: Python 3.11
    netsh advfirewall firewall add rule name="GPS Field Assist - Python 311" dir=in action=allow program="C:\Users\Asus\AppData\Local\Programs\Python\Python311\python.exe" enable=yes
)

REM Python 3.10
if exist "C:\Users\Asus\AppData\Local\Programs\Python\Python310\python.exe" (
    echo Trouve: Python 3.10
    netsh advfirewall firewall add rule name="GPS Field Assist - Python 310" dir=in action=allow program="C:\Users\Asus\AppData\Local\Programs\Python\Python310\python.exe" enable=yes
)

REM Python dans Program Files
if exist "C:\Program Files\Python313\python.exe" (
    echo Trouve: Python 3.13 (Program Files)
    netsh advfirewall firewall add rule name="GPS Field Assist - Python 313 PF" dir=in action=allow program="C:\Program Files\Python313\python.exe" enable=yes
)

REM Python venv - utilise le chemin correct
if exist "C:\gps-field-assist_5th_ver_corrige\backend\venv\Scripts\python.exe" (
    echo Trouve: Python venv (gps-field-assist)
    netsh advfirewall firewall add rule name="GPS Field Assist - Python venv" dir=in action=allow program="C:\gps-field-assist_5th_ver_corrige\backend\venv\Scripts\python.exe" enable=yes
)

echo.
echo Autorisation du port 8000...
netsh advfirewall firewall add rule name="GPS Field Assist - Port 8000" dir=in action=allow protocol=TCP localport=8000 enable=yes

echo.
echo ========================================
echo Configuration terminee!
echo.
echo Les regles suivantes ont ete ajoutees:
netsh advfirewall firewall show rule name="GPS Field Assist"
echo ========================================
pause

