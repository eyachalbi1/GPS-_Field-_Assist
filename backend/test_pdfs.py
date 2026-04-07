import requests
from urllib.parse import quote

API_BASE = "http://41.226.24.13:5000"

# Récupérer la liste
r = requests.get(f"{API_BASE}/api/files")
data = r.json()
files = data.get("files", data) if isinstance(data, dict) else data
print(f"PDFs trouvés: {files}\n")

# Tester chaque PDF
for fname in files:
    encoded = quote(fname)
    for url in [
        f"{API_BASE}/api/download/{encoded}",
        f"{API_BASE}/api/files/download/{encoded}",
    ]:
        r = requests.get(url, timeout=10)
        if r.status_code == 200 and len(r.content) > 100:
            print(f"OK  [{len(r.content)//1024}KB] {fname} -> {url}")
            break
    else:
        print(f"FAIL {fname}")
