"""
Prediction IA des taches : modele ML reel entraine sur les donnees de la DB.
- LinearRegression pour predire la charge de la semaine prochaine
- Groq LLM pour generer des insights textuels dynamiques
"""
import os
from datetime import datetime, timedelta
from collections import defaultdict

import numpy as np
from sklearn.linear_model import LinearRegression
from dotenv import load_dotenv

from src.models.database import get_db

load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")


def _fetch_tasks_for_user(user_id: int) -> list[dict]:
    """Recupere toutes les taches de l'utilisateur depuis la DB."""
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT id,
                           COALESCE(subject, name, '') AS name,
                           COALESCE(description, '')   AS description,
                           COALESCE(stage, status, 'a_faire') AS status,
                           created_at,
                           start_time,
                           end_time
                    FROM tasks
                    WHERE assigned_to_id = %s::text
                    ORDER BY created_at ASC
                """, (str(user_id),))
                return [dict(r) for r in cur.fetchall()]
    except Exception:
        return []


def _build_weekly_series(tasks: list[dict]) -> list[int]:
    """Construit une serie temporelle : nb de taches par semaine (12 dernieres semaines)."""
    now = datetime.now()
    counts = [0] * 12
    for t in tasks:
        dt = t.get("created_at")
        if not dt:
            continue
        try:
            if not isinstance(dt, datetime):
                dt = datetime.fromisoformat(str(dt).replace("Z", ""))
            diff = (now - dt).days
            idx = diff // 7
            if 0 <= idx < 12:
                counts[11 - idx] += 1
        except Exception:
            continue
    return counts


def _train_and_predict(series: list[int]) -> dict:
    """
    Entraine un LinearRegression sur la serie temporelle et predit la semaine suivante.
    Retourne la prediction + le score R2 du modele.
    """
    if len(series) < 3 or sum(series) == 0:
        return {"predicted": 0, "r2": 0.0, "confidence": "faible"}

    X = np.array(range(len(series))).reshape(-1, 1)
    y = np.array(series)

    model = LinearRegression()
    model.fit(X, y)

    r2 = float(model.score(X, y))
    next_week_idx = np.array([[len(series)]])
    predicted = max(0, round(float(model.predict(next_week_idx)[0])))

    confidence = "elevee" if r2 >= 0.6 else "moderee" if r2 >= 0.3 else "faible"
    return {"predicted": predicted, "r2": round(r2, 3), "confidence": confidence}


def _detect_task_types(tasks: list[dict]) -> dict:
    """Compte les types de taches detectes dans les descriptions."""
    keywords = {
        "installation": ["install", "pose", "montage", "mise en place"],
        "maintenance":  ["mainten", "entretien", "verif", "nettoy"],
        "diagnostic":   ["diagnost", "panne", "probleme", "erreur"],
        "configuration":["config", "parametr", "apn", "reglage"],
        "remplacement": ["remplac", "chang", "swap"],
    }
    counts = defaultdict(int)
    for t in tasks:
        text = (t.get("name", "") + " " + t.get("description", "")).lower()
        for ttype, kws in keywords.items():
            if any(k in text for k in kws):
                counts[ttype] += 1
    return dict(counts)


def _groq_insight(username: str, series: list[int], prediction: int,
                  task_types: dict, pending: int) -> str:
    """Genere un insight textuel via Groq LLM base sur les vraies donnees."""
    if not GROQ_API_KEY:
        return _fallback_insight(series, prediction, pending)

    try:
        from groq import Groq
        client = Groq(api_key=GROQ_API_KEY)

        top_type = max(task_types, key=task_types.get) if task_types else "intervention"
        recent4  = series[-4:]
        trend    = "croissante" if recent4[-1] > recent4[0] else "decroissante" if recent4[-1] < recent4[0] else "stable"

        prompt = (
            f"Technicien GPS : {username}\n"
            f"Historique 12 semaines (taches/semaine) : {series}\n"
            f"Tendance recente : {trend}\n"
            f"Type de tache dominant : {top_type} ({task_types.get(top_type, 0)} taches)\n"
            f"Taches en attente : {pending}\n"
            f"Prediction semaine prochaine : {prediction} taches\n\n"
            "En 2 phrases courtes en francais, donne un conseil operationnel concret "
            "pour ce technicien GPS. Sois direct, pas d'introduction."
        )

        resp = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": "Tu es un assistant de gestion d'equipe GPS terrain. Reponds en francais, 2 phrases max."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.4,
            max_tokens=120,
        )
        return resp.choices[0].message.content.strip()
    except Exception:
        return _fallback_insight(series, prediction, pending)


def _fallback_insight(series: list[int], prediction: int, pending: int) -> str:
    recent = series[-1] if series else 0
    if prediction > recent * 1.3:
        return f"Charge en hausse prevue ({prediction} taches). Planifiez vos interventions en avance."
    if prediction < recent * 0.7:
        return f"Charge en baisse prevue ({prediction} taches). Bon moment pour les maintenances preventives."
    return f"Charge stable prevue ({prediction} taches). {pending} taches en attente a traiter."


def get_task_predictions(user_id: int, username: str) -> dict:
    """
    Point d'entree principal : retourne les predictions IA pour un technicien.
    """
    tasks = _fetch_tasks_for_user(user_id)

    completed_statuses = {"termine", "done", "completed", "Done", "resolu"}
    completed = [t for t in tasks if (t.get("status") or "") in completed_statuses]
    pending   = [t for t in tasks if (t.get("status") or "") not in completed_statuses]

    series     = _build_weekly_series(tasks)
    ml_result  = _train_and_predict(series)
    task_types = _detect_task_types(tasks)
    insight    = _groq_insight(username, series, ml_result["predicted"], task_types, len(pending))

    # Tendance
    recent4 = series[-4:]
    prev4   = series[-8:-4]
    sum_r   = sum(recent4)
    sum_p   = sum(prev4)
    if sum_p == 0:
        trend_pct, trend = 0, "stable"
    else:
        trend_pct = round((sum_r - sum_p) / sum_p * 100)
        trend = "hausse" if trend_pct > 10 else "baisse" if trend_pct < -10 else "stable"

    # Pic de la semaine (jour le plus charge)
    now = datetime.now()
    day_counts = defaultdict(int)
    for t in tasks:
        dt = t.get("created_at")
        if not dt:
            continue
        try:
            if not isinstance(dt, datetime):
                dt = datetime.fromisoformat(str(dt).replace("Z", ""))
            if (now - dt).days <= 30:
                day_counts[dt.strftime("%A")] += 1
        except Exception:
            continue

    busiest_day = max(day_counts, key=day_counts.get) if day_counts else None

    return {
        "username":        username,
        "total_tasks":     len(tasks),
        "completed":       len(completed),
        "pending":         len(pending),
        "weekly_history":  series,
        "predicted_next_week": ml_result["predicted"],
        "model_confidence":    ml_result["confidence"],
        "model_r2":            ml_result["r2"],
        "trend":               trend,
        "trend_pct":           trend_pct,
        "task_types":          task_types,
        "busiest_day":         busiest_day,
        "ai_insight":          insight,
    }
