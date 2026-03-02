' Script VBS pour demarrer le serveur en arriere-plan
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "cmd /k cd /d """ & CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & """ && python -m uvicorn main:app --host 0.0.0.0 --port 8000", 0, False
