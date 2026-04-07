import sys
sys.path.insert(0, 'src')
import time

print("Test indexation...")
start = time.time()
from services.pdf_ai_service import build_index, search, answer, _index

build_index()
elapsed = time.time() - start
print(f"Index construit en {elapsed:.1f}s — {len(_index)} chunks\n")

# Test recherche
tests = [
    "comment configurer l'APN",
    "commande SMS pour position GPS",
    "reset du module",
    "IP serveur configuration",
]
for q in tests:
    hits = search(q, top_k=3)
    print(f"Q: {q}")
    for h in hits:
        print(f"  [{h['filename']} p.{h['page']}] score={h['score']} — {h['text'][:80]}...")
    print()
