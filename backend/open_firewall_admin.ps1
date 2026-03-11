# Auto-elevate and open firewall
param(
    [string]$Port = "8000",
    [string]$RuleName = "GPS Field Assist"
)

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script needs administrator privileges." -ForegroundColor Red
    Write-Host "Attempting to restart as Administrator..." -ForegroundColor Yellow
    
    # Try to restart as admin
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -Port $Port -RuleName `"$RuleName`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    exit
}

# If we get here, we're running as admin
Write-Host "Opening port $Port for $RuleName..." -ForegroundColor Green

# Add firewall rule
$result = netsh advfirewall firewall add rule name="$RuleName - Port $Port" dir=in action=allow protocol=TCP localport=$Port

if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS: Port $Port is now open!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your server should now be accessible from your phone at:" -ForegroundColor Cyan
    Write-Host "  http://192.168.2.115:$Port" -ForegroundColor White
} else {
    Write-Host "ERROR: Failed to open port. $result" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

