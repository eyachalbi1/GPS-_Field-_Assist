# Open Firewall for GPS Field Assist
# Run as Administrator

Write-Host "Opening Firewall for GPS Field Assist..." -ForegroundColor Cyan

# Allow Python through firewall
$pythonPath = "C:\gps-field-assist_5th_ver_corrige\backend\venv\Scripts\python.exe"
if (Test-Path $pythonPath) {
    Write-Host "Adding rule for Python..." -ForegroundColor Yellow
    netsh advfirewall firewall add rule name="GPS Field Assist - Python" dir=in action=allow program="$pythonPath" enable=yes
}

# Allow port 8000
Write-Host "Adding rule for port 8000..." -ForegroundColor Yellow
netsh advfirewall firewall add rule name="GPS Field Assist - Port 8000" dir=in action=allow protocol=TCP localport=8000 enable=yes

Write-Host ""
Write-Host "Firewall rules added:" -ForegroundColor Green
netsh advfirewall firewall show rule name="GPS Field Assist"

Write-Host ""
Write-Host "Done! Try connecting from your phone." -ForegroundColor Green

