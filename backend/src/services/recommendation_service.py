"""
Recommandations personnalisées par intervention :
- Outils et pièces nécessaires selon le type de tâche
- Tutoriels pertinents selon la nature de la tâche
- Estimation de durée basée sur l'historique des interventions similaires
"""
import os
import re
from dotenv import load_dotenv
from src.models.database import get_db

load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")

# ── Base de connaissances ──────────────────────────────────────────────────────

TOOLS_BY_TYPE = {
    "installation": ["Multimètre", "Tournevis cruciforme", "Pince coupante", "Câble alimentation 12V", "Connecteurs étanches", "Ruban isolant"],
    "maintenance":  ["Multimètre", "Chiffon microfibre", "Spray contact", "Tournevis plat", "Pince à dénuder"],
    "diagnostic":   ["Multimètre", "Câble OBD", "Téléphone avec SIM active", "Chargeur de batterie"],
    "configuration":["Téléphone avec SIM active", "Câble USB-TTL", "Ordinateur portable"],
    "remplacement": ["Tournevis cruciforme", "Pince coupante", "Module GPS de remplacement", "Connecteurs", "Ruban isolant"],
    "default":      ["Multimètre", "Tournevis cruciforme", "Téléphone avec SIM active"],
}

PARTS_BY_TYPE = {
    "installation": ["Boîtier GPS", "Câble alimentation", "Antenne GPS externe", "Fusible 1A"],
    "maintenance":  ["Fusible 1A", "Connecteurs de rechange"],
    "diagnostic":   [],
    "configuration":[],
    "remplacement": ["Boîtier GPS", "Câble alimentation", "Antenne GPS externe"],
    "default":      [],
}

TUTORIALS_BY_TYPE = {
    "installation": [
        {"title": "Installation GT06N — Guide complet", "module": "GT06N"},
        {"title": "Câblage alimentation 12V", "module": "général"},
        {"title": "Configuration APN opérateur", "module": "général"},
    ],
    "maintenance": [
        {"title": "Nettoyage et vérification des connexions", "module": "général"},
        {"title": "Test de signal GPS en terrain", "module": "général"},
    ],
    "diagnostic": [
        {"title": "Commandes SMS de diagnostic GT06N", "module": "GT06N"},
        {"title": "Commandes SMS FM4200", "module": "FM4200"},
        {"title": "Interprétation des réponses SMS", "module": "général"},
    ],
    "configuration": [
        {"title": "Configuration APN Orange/Ooredoo/Telecom", "module": "général"},
        {"title": "Paramétrage serveur de tracking", "module": "général"},
    ],
    "remplacement": [
        {"title": "Remplacement boîtier GPS", "module": "général"},
        {"title": "Test post-installation", "module": "général"},
    ],
    "default": [
        {"title": "Guide d'intervention terrain", "module": "général"},
    ],
}


# ── Détection du type de tâche ─────────────────────────────────────────────────

def _detect_type(name: str, description: str) -> str:
    text = (name + " " + description).lower()
    if any(w in text for w in ["install", "pose", "montage", "mise en place"]):
        return "installation"
    if any(w in text for w in ["mainten", "entretien", "vérif", "verif", "nettoy"]):
        return "maintenance"
    if any(w in text for w in ["diagnost", "panne", "problème", "probleme", "erreur", "défaut"]):
        return "diagnostic"
    if any(w in text for w in ["config", "paramètr", "parametr", "apn", "réglage"]):
        return "configuration"
    if any(w in text for w in ["remplac", "chang", "swap"]):
        return "remplacement"
    return "default"


# ── Estimation de durée ────────────────────────────────────────────────────────

def _estimate_duration(task_type: str) -> dict:
    """
    Calcule la durée moyenne des interventions similaires depuis la DB.
    Fallback sur des valeurs par défaut si pas assez de données.
    """
    defaults = {
        "installation": 90,
        "maintenance":  45,
        "diagnostic":   30,
        "configuration":20,
        "remplacement": 60,
        "default":      45,
    }

    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                # Chercher les tâches terminées avec des horaires renseignés
                cur.execute("""
                    SELECT start_time, end_time, name, description
                    FROM tasks
                    WHERE status = 'termine'
                    AND start_time IS NOT NULL AND end_time IS NOT NULL
                    AND start_time != '' AND end_time != ''
                """)
                rows = cur.fetchall()
    except Exception:
        rows = []

    durations = []
    for row in rows:
        detected = _detect_type(row["name"] or "", row["description"] or "")
        if detected != task_type:
            continue
        try:
            # Format attendu : "HH:MM" ou "Xh"
            def parse_h(t):
                t = str(t).strip()
                if "h" in t:
                    parts = t.replace("h", ":").split(":")
                    return int(parts[0]) * 60 + (int(parts[1]) if len(parts) > 1 and parts[1] else 0)
                if ":" in t:
                    p = t.split(":")
                    return int(p[0]) * 60 + int(p[1])
                return None

            start = parse_h(row["start_time"])
            end   = parse_h(row["end_time"])
            if start is not None and end is not None and end > start:
                durations.append(end - start)
        except Exception:
            continue

    if len(durations) >= 2:
        avg = round(sum(durations) / len(durations))
        return {"minutes": avg, "source": "historique", "sample_size": len(durations)}

    default_min = defaults.get(task_type, 45)
    return {"minutes": default_min, "source": "estimation", "sample_size": 0}


# ── Enrichissement Groq LLM ───────────────────────────────────────────────────

def _groq_task_insight(name: str, description: str, task_type: str,
                       tools: list, duration: dict) -> str:
    if not GROQ_API_KEY:
        return ""
    try:
        from groq import Groq
        client = Groq(api_key=GROQ_API_KEY)
        prompt = (
            f"Intervention GPS : {name}\n"
            f"Description : {description or 'non fournie'}\n"
            f"Type detecte : {task_type}\n"
            f"Outils prevus : {tools}\n"
            f"Duree estimee : {duration['minutes']} min ({duration['source']})\n\n"
            "En 2 phrases courtes en francais, donne un conseil pratique specifique "
            "pour reussir cette intervention GPS terrain. Sois direct, sans introduction."
        )
        resp = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": "Expert GPS terrain. 2 phrases max en francais."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.3,
            max_tokens=120,
        )
        return resp.choices[0].message.content.strip()
    except Exception as e:
        print(f"[recommendation] Groq error: {e}")
    return ""


# ── Point d'entrée principal ───────────────────────────────────────────────────

def get_task_recommendations(name: str, description: str) -> dict:
    task_type  = _detect_type(name, description)
    duration   = _estimate_duration(task_type)
    tools      = TOOLS_BY_TYPE.get(task_type, TOOLS_BY_TYPE["default"])
    ai_insight = _groq_task_insight(name, description, task_type, tools, duration)

    return {
        "task_type":   task_type,
        "tools":       tools,
        "parts":       PARTS_BY_TYPE.get(task_type, []),
        "tutorials":   TUTORIALS_BY_TYPE.get(task_type, TUTORIALS_BY_TYPE["default"]),
        "duration":    duration,
        "ai_insight":  ai_insight,
        "ai_enhanced": bool(ai_insight),
    }
