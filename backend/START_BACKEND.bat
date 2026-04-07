@echo off
title GPS Field Assist - Backend
cd /d "C:\1.0_ejdida_1_3_4\backend"
echo Demarrage du serveur...
"C:\Users\EYA CHALBI\AppData\Local\Programs\Python\Python310\python.exe" -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
pause
