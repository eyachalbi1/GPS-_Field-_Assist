' Script VBS pour demarrer le serveur GPS Field Assist en arriere-plan au demarrage
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """C:\Users\Asus\AppData\Local\Programs\Python\Python313\python.exe"" -m uvicorn main:app --host 0.0.0.0 --port 8000", 0, False
