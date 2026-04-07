@echo off
set PY="C:\Users\EYA CHALBI\AppData\Local\Programs\Python\Python310\python.exe"
%PY% -c "from groq import Groq; c=Groq(api_key='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'); r=c.chat.completions.create(model='llama-3.3-70b-versatile',messages=[{'role':'user','content':'Dis bonjour en francais'}],max_tokens=50); print(r.choices[0].message.content)"
