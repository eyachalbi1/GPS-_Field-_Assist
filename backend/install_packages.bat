@echo off
set PY="C:\Users\EYA CHALBI\AppData\Local\Programs\Python\Python310\python.exe"
%PY% -m pip install pdfplumber==0.11.0 scikit-learn numpy fastapi==0.104.1 uvicorn==0.24.0 python-multipart==0.0.6 passlib==1.7.4 bcrypt==4.0.1 PyJWT==2.8.0 python-dotenv==1.0.0 psycopg2-binary==2.9.7 httpx==0.28.1 2>&1
echo.
echo Done!
