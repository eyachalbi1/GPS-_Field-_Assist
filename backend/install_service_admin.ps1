# Script pour installer le service GPS Field Assist - A executer en tant qu'admin
cd "C:\Users\Asus\Desktop\gps-field-assist_ver_2_1_2\backend"

Write-Host "Installation du service GPSFieldAssist..." -ForegroundColor Cyan

# Chemin vers Python
$pythonPath = "C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe"
$appPath = "C:\Users\Asus\Desktop\gps-field-assist_ver_2_1_2\backend"

# Installer le service avec NSSM
& .\nssm.exe install GPSFieldAssist $pythonPath "-m uvicorn main:app --host 0.0.0.0 --port 8000"

# Configurer le repertoire de l'application
& .\nssm.exe set GPSFieldAssist AppDirectory $appPath

# Demarrer le service
Start-Service -Name GPSFieldAssist

Write-Host "Service installe et demarre!" -ForegroundColor Green
Write-Host "Le serveur est disponible sur http://localhost:8000" -ForegroundColor Green
