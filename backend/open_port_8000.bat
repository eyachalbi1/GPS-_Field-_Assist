@echo off
echo Opening port 8000 for GPS Field Assist...
echo.
echo Run this file as Administrator (Right-click -> Run as administrator)
echo.
pause
netsh advfirewall firewall add rule name="GPS Field Assist - Port 8000" dir=in action=allow protocol=TCP localport=8000
echo.
echo Done! Port 8000 is now open.
echo.
pause

