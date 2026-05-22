import os
import re
import io
import threading
import requests
import pdfplumber
from groq import Groq
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from dotenv import load_dotenv
import numpy as np

load_dotenv()

API_BASE     = os.getenv("API_BASE_URL", "http://41.226.24.13:5000")
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
MODULES_DIR  = os.path.join(os.getcwd(), "static", "modules")

_index: list[dict] = []
_vectorizer: TfidfVectorizer | None = None
_matrix = None
_groq_client: Groq | None = None
_index_lock = threading.Lock()
_indexed = False
_api_reachable: bool | None = None  # None = untested


def _get_groq() -> Groq | None:
    global _groq_client
    if _groq_client is None and GROQ_API_KEY:
        _groq_client = Groq(api_key=GROQ_API_KEY)
    return _groq_client


# ── Extraction PDF ─────────────────────────────────────────────────────────────

def _chunk_text(text: str, max_chars: int = 600) -> list[str]:
    """Découpe le texte en chunks par paragraphes, max max_chars chacun."""
    paragraphs = [p.strip() for p in re.split(r'\n{2,}', text) if len(p.strip()) > 40]
    chunks, current = [], ""
    for p in paragraphs:
        if len(current) + len(p) < max_chars:
            current += " " + p
        else:
            if current:
                chunks.append(current.strip())
            current = p
    if current:
        chunks.append(current.strip())
    return chunks or [text[:max_chars]]


def _extract_pdf_bytes(pdf_bytes: bytes, filename: str) -> list[dict]:
    chunks = []
    try:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            for page in pdf.pages:
                text = page.extract_text() or ""
                for table in page.extract_tables():
                    for row in table:
                        text += " ".join(cell or "" for cell in row) + " "
                text = text.strip()
                if len(text) < 30:
                    continue
                for chunk in _chunk_text(text):
                    chunks.append({
                        "filename": filename,
                        "page": page.page_number,
                        "text": chunk,
                    })
    except Exception as e:
        print(f"[pdf_ai] extraction error {filename}: {e}")
    return chunks


def _check_api_reachable() -> bool:
    global _api_reachable
    if _api_reachable is not None:
        return _api_reachable
    try:
        requests.get(f"{API_BASE}/api/files", timeout=5)
        _api_reachable = True
    except Exception:
        _api_reachable = False
    return _api_reachable


def _fetch_pdf_list() -> list[str]:
    if _check_api_reachable():
        try:
            r = requests.get(f"{API_BASE}/api/files", timeout=15)
            if r.status_code == 200:
                data = r.json()
                raw = data if isinstance(data, list) else data.get("files", [])
                return [
                    (f["filename"] if isinstance(f, dict) else str(f))
                    for f in raw
                    if (f["filename"] if isinstance(f, dict) else str(f)).lower().endswith(".pdf")
                ]
        except Exception as e:
            print(f"[pdf_ai] fetch list error: {e}")
    else:
        print(f"[pdf_ai] API unreachable, using local PDFs from {MODULES_DIR}")
    if os.path.exists(MODULES_DIR):
        return [f for f in os.listdir(MODULES_DIR) if f.lower().endswith(".pdf")]
    return []


def _fetch_pdf_bytes(filename: str) -> bytes | None:
    # Cache local pour eviter re-telechargement
    cache_dir = os.path.join(os.getcwd(), 'static', 'pdf_cache')
    os.makedirs(cache_dir, exist_ok=True)
    cache_path = os.path.join(cache_dir, filename.replace('/', '_').replace(' ', '_'))

    if os.path.exists(cache_path):
        with open(cache_path, 'rb') as f:
            print(f"[pdf_ai] cache hit: {filename}")
            return f.read()

    # Try local first if API is known unreachable
    local = os.path.join(MODULES_DIR, filename)
    if not _check_api_reachable():
        if os.path.exists(local):
            with open(local, 'rb') as f:
                return f.read()
        return None

    from urllib.parse import quote
    encoded = quote(filename)
    for url in [
        f"{API_BASE}/api/download/{encoded}",
        f"{API_BASE}/api/files/download/{encoded}",
        f"{API_BASE}/modules/{encoded}",
    ]:
        try:
            r = requests.get(url, timeout=30)
            if r.status_code == 200 and len(r.content) > 100:
                print(f"[pdf_ai] downloaded {filename} from {url}")
                with open(cache_path, 'wb') as f:
                    f.write(r.content)
                return r.content
        except Exception as e:
            print(f"[pdf_ai] error {url}: {e}")
    if os.path.exists(local):
        with open(local, 'rb') as f:
            return f.read()
    return None


# ── Index ──────────────────────────────────────────────────────────────────────

def build_index():
    global _index, _vectorizer, _matrix, _indexed
    with _index_lock:
        _index = []
        filenames = _fetch_pdf_list()
        print(f"[pdf_ai] indexing {len(filenames)} PDFs from {API_BASE}")
        for fname in filenames:
            pdf_bytes = _fetch_pdf_bytes(fname)
            if not pdf_bytes:
                continue
            chunks = _extract_pdf_bytes(pdf_bytes, fname)
            _index.extend(chunks)
            print(f"[pdf_ai] {fname}: {len(chunks)} chunks")

        if not _index:
            print("[pdf_ai] no content indexed")
            return

        texts = [c["text"] for c in _index]
        _vectorizer = TfidfVectorizer(
            ngram_range=(1, 3),
            max_features=30000,
            sublinear_tf=True,
        )
        _matrix = _vectorizer.fit_transform(texts)
        _indexed = True
        print(f"[pdf_ai] index ready: {len(_index)} chunks from {len(filenames)} PDFs")


def _ensure_index():
    if not _indexed:
        build_index()


# ── Recherche ──────────────────────────────────────────────────────────────────

def search(query: str, top_k: int = 8) -> list[dict]:
    _ensure_index()
    if _vectorizer is None or _matrix is None:
        return []
    q_vec = _vectorizer.transform([query])
    scores = cosine_similarity(q_vec, _matrix).flatten()
    top_idx = np.argsort(scores)[::-1][:top_k]
    results = []
    seen_texts = set()
    for i in top_idx:
        if scores[i] < 0.03:
            continue
        text = _index[i]["text"]
        # Dédupliquer les chunks très similaires
        key = text[:80]
        if key in seen_texts:
            continue
        seen_texts.add(key)
        results.append({**_index[i], "score": round(float(scores[i]), 4)})
    return results


# ── Réponse ────────────────────────────────────────────────────────────────────

def answer(question: str) -> dict:
    hits = search(question, top_k=8)

    # Construire le contexte depuis les meilleurs chunks
    context_parts = []
    sources = []
    seen_files = set()
    for h in hits:
        context_parts.append(f"[{h['filename']} p.{h['page']}]\n{h['text']}")
        if h["filename"] not in seen_files:
            sources.append({"filename": h["filename"], "score": h["score"]})
            seen_files.add(h["filename"])

    context = "\n\n".join(context_parts[:6])  # max 6 chunks

    groq = _get_groq()
    if groq:
        try:
            system_prompt = (
                "Tu es un assistant technique expert GPS pour techniciens de terrain. "
                "Tu as accès aux manuels GPS suivants. "
                "Règles STRICTES :\n"
                "1. Réponds UNIQUEMENT en français.\n"
                "2. Sois direct et précis — max 4 phrases courtes ou une liste numérotée.\n"
                "3. Si la réponse est dans le contexte, utilise-la exactement.\n"
                "4. Si ce n'est pas dans le contexte, utilise tes connaissances GPS.\n"
                "5. Jamais d'introduction ni de conclusion.\n"
                "6. Pour les commandes SMS/AT, affiche-les en format code."
            )

            user_msg = question
            if context.strip():
                user_msg = (
                    f"Contexte extrait des manuels GPS :\n\n{context}\n\n"
                    f"Question du technicien : {question}"
                )

            completion = groq.chat.completions.create(
                model="llama-3.3-70b-versatile",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user",   "content": user_msg},
                ],
                temperature=0.2,
                max_tokens=400,
            )
            answer_text = completion.choices[0].message.content.strip()
            return {"answer": answer_text, "sources": sources}
        except Exception as e:
            print(f"[pdf_ai] Groq error: {e}")

    # Fallback TF-IDF
    if not hits:
        return {"answer": "Aucune information trouvée dans les documents.", "sources": []}
    best = hits[0]["text"]
    sentences = re.split(r"(?<=[.!?])\s+", best)
    q_words = set(question.lower().split())
    best_sent = max(sentences, key=lambda s: len(q_words & set(s.lower().split())), default=best)
    return {"answer": best_sent.strip(), "sources": sources}


# ── Auto-indexation au démarrage ───────────────────────────────────────────────
def _auto_index():
    """Lance l'indexation en arrière-plan au démarrage du serveur."""
    t = threading.Thread(target=build_index, daemon=True)
    t.start()

_auto_index()
