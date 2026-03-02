# PowerShell script to install GPS Field Assist as a Windows Service
# Run as Administrator

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "GPS Field Assist - Service Installation" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$backendDir = "C:\Users\Asus\Desktop\gps-field-assist_ver_2_1_2\backend"
$pythonExe = "C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe"

# Check if NSSM exists
$nssmPath = "$backendDir\nssm.exe"
if (-not (Test-Path $nssmPath)) {
    Write-Host "Downloading NSSM..." -ForegroundColor Yellow
    
    # Download NSSM
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile("https://nssm.cc/release/nssm-2.24.zip", "$backendDir\nssm.zip")
    
    # Extract
    Expand-Archive -Path "$backendDir\nssm.zip" -DestinationPath $backendDir -Force
    Copy-Item "$backendDir\nssm-2.24\win64\nssm.exe" $nssmPath -Force
    
    # Cleanup
    Remove-Item "$backendDir\nssm.zip" -Force
    Remove-Item "$backendDir\nssm-2.24" -Recurse -Force
    
    Write-Host "NSSM installed!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installing service..." -ForegroundColor Yellow

# Install service
& $nssmPath install GPSFieldAssist $pythonExe "-m uvicorn main:app --host 0.0.0.0 --port 8000"
& $nssmPath set GPSFieldAssist AppDirectory $backendDir
& $nssmPath set GPSFieldAssist Description "GPS Field Assist Backend Server"
& $nssmPath set GPSFieldAssist DisplayName "GPS Field Assist"

Write-Host ""
Write-Host "Service installed!" -ForegroundColor Green
Write-Host ""
Write-Host "To start the service:" -ForegroundColor Cyan
Write-Host "  net start GPSFieldAssist" -ForegroundColor White
Write-Host ""
Write-Host "To stop the service:" -ForegroundColor Cyan
Write-Host "  net stop GPSFieldAssist" -ForegroundColor White
Write-Host ""
Write-Host "The service will start automatically at PC boot!" -ForegroundColor Green
