@echo off
echo Ouverture du port 5000 dans le pare-feu Windows...
netsh advfirewall firewall add rule name="GPS Field Assist Port 5000" dir=in action=allow protocol=TCP localport=5000
echo.
echo Port 5000 ouvert. Le mobile peut maintenant se connecter.
pause
