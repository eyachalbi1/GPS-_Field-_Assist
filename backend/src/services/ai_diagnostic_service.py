"""
Moteur de recommandation SMS + maintenance prédictive par séries temporelles.
"""
import os
import re
from collections import defaultdict, Counter
from datetime import datetime, timedelta
from dotenv import load_dotenv
from src.models.database import get_db

load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")

# ── Commandes SMS par symptôme et type d'équipement ───────────────────────────
SMS_RECOMMENDATIONS = {
    "pas de signal": {
        "GT06N":   ["STATUS", "GPSON", "RESET"],
        "FM4200":  ["getinfo", "setparam 2000:1", "reboot"],
        "ET7":     ["INFO", "GPSON", "RESET"],
        "default": ["STATUS", "GPSON"],
    },
    "pas de position": {
        "GT06N":   ["GPSON", "RESET"],
        "FM4200":  ["getinfo", "setparam 2000:1"],
        "default": ["GPSON", "STATUS"],
    },
    "hors ligne": {
        "GT06N":   ["STATUS", "APN,<apn>,<user>,<pass>", "RESET"],
        "FM4200":  ["getinfo", "setparam 1242:<apn>", "reboot"],
        "default": ["STATUS", "APN"],
    },
    "batterie": {
        "GT06N":   ["STATUS"],
        "FM4200":  ["getinfo"],
        "default": ["STATUS"],
    },
    "installation": {
        "GT06N":   ["BEGIN,<password>", "APN,<apn>", "GPSON", "STATUS"],
        "FM4200":  ["getver", "setparam 1242:<apn>", "getinfo"],
        "default": ["STATUS", "GPSON"],
    },
}

def _match_symptom(description: str) -> str | None:
    desc = description.lower()
    for symptom in SMS_RECOMMENDATIONS:
        if symptom in desc:
            return symptom
    return None

def _match_equipment(name: str) -> str:
    name_up = name.upper()
    for eq in ["GT06N", "FM4200", "FM5300", "FMA120", "ET7", "EASYTRACE"]:
        if eq in name_up:
            return eq
    return "default"


# ── Recommandation SMS ─────────────────────────────────────────────────────────

def _groq_sms_recommendations(equipment_type: str, symptom: str, base_cmds: list) -> dict:
    """Enrichit les recommandations SMS via Groq LLM."""
    if not GROQ_API_KEY:
        return {}
    try:
        import json
        from groq import Groq
        client = Groq(api_key=GROQ_API_KEY)
        prompt = (
            f"Equipement GPS : {equipment_type or 'inconnu'}\n"
            f"Symptome : {symptom or 'inconnu'}\n"
            f"Commandes SMS de base : {base_cmds}\n\n"
            "Reponds UNIQUEMENT avec ce JSON valide :\n"
            '{"sms_commands": [...], "diagnostic_steps": [...], "cause_probable": "..."}\n'
            "- sms_commands : commandes SMS a envoyer dans l ordre (max 5)\n"
            "- diagnostic_steps : etapes terrain courtes (max 3)\n"
            "- cause_probable : cause la plus probable en 1 phrase"
        )
        resp = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": "Expert GPS terrain. Reponds uniquement en JSON valide, sans texte autour."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.2,
            max_tokens=300,
        )
        text = resp.choices[0].message.content.strip()
        start, end = text.find('{'), text.rfind('}') + 1
        if start >= 0 and end > start:
            return json.loads(text[start:end])
    except Exception as e:
        print(f"[ai_diag] Groq error: {e}")
    return {}


def get_recommendations(equipment_type: str = "", symptom: str = "") -> dict:
    """
    Analyse les taches recurrentes et retourne les commandes SMS recommandees
    pour le symptome + equipement donnes — enrichies par Groq LLM.
    """
    symptom_key = _match_symptom(symptom) if symptom else None
    eq_key = _match_equipment(equipment_type) if equipment_type else "default"

    recurring = _get_recurring_issues()

    if not symptom_key:
        if recurring:
            symptom_key = recurring[0]["symptom"]
        else:
            return {"recommendations": [], "recurring_issues": recurring}

    cmds_map = SMS_RECOMMENDATIONS.get(symptom_key, {})
    base_cmds = cmds_map.get(eq_key) or cmds_map.get("default", [])

    ai_result = _groq_sms_recommendations(equipment_type, symptom or symptom_key, base_cmds)

    return {
        "symptom": symptom_key,
        "equipment": eq_key,
        "sms_commands": ai_result.get("sms_commands", base_cmds),
        "diagnostic_steps": ai_result.get("diagnostic_steps", []),
        "cause_probable": ai_result.get("cause_probable", ""),
        "recurring_issues": recurring[:5],
        "ai_enhanced": bool(ai_result),
    }


def _get_recurring_issues() -> list[dict]:
    """Compte les symptômes récurrents dans les descriptions de tâches."""
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT description, name FROM tasks WHERE description IS NOT NULL")
                rows = cur.fetchall()
    except Exception:
        return []

    counts: Counter = Counter()
    for row in rows:
        desc = (row["description"] or "").lower()
        name = (row["name"] or "").lower()
        for symptom in SMS_RECOMMENDATIONS:
            if symptom in desc or symptom in name:
                counts[symptom] += 1

    return [{"symptom": s, "count": c} for s, c in counts.most_common(5)]


# ── Maintenance prédictive ─────────────────────────────────────────────────────

def get_predictive_alerts() -> dict:
    """
    Détecte les équipements à risque via analyse de séries temporelles simples :
    - Fréquence d'interventions par équipement sur les 30 derniers jours
    - Tendance croissante = risque élevé
    """
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT name, partner_name, status, created_at
                    FROM tasks
                    WHERE created_at >= NOW() - INTERVAL '90 days'
                    ORDER BY created_at ASC
                """)
                rows = cur.fetchall()
    except Exception:
        return {"alerts": [], "at_risk": []}

    # Grouper par équipement (partner_name comme proxy)
    timeline: dict[str, list[datetime]] = defaultdict(list)
    for row in rows:
        key = row["partner_name"] or row["name"] or "inconnu"
        if row["created_at"]:
            timeline[key].append(row["created_at"])

    alerts = []
    at_risk = []
    now = datetime.now()

    for equipment, dates in timeline.items():
        if len(dates) < 2:
            continue

        # Compter par fenêtre de 30j vs 30j précédents
        recent = sum(1 for d in dates if (now - d).days <= 30)
        older  = sum(1 for d in dates if 30 < (now - d).days <= 60)

        # Tendance : augmentation > 50% = risque
        if older > 0 and recent >= older * 1.5 and recent >= 2:
            trend = round((recent - older) / older * 100)
            at_risk.append({
                "equipment": equipment,
                "interventions_recent": recent,
                "interventions_prev": older,
                "trend_pct": trend,
                "risk": "élevé" if trend >= 100 else "modéré",
            })

        # Alerte si >= 3 interventions en 30j
        if recent >= 3:
            # Estimer prochaine intervention (moyenne des intervalles)
            intervals = [(dates[i+1] - dates[i]).days for i in range(len(dates)-1)]
            avg_interval = sum(intervals) / len(intervals) if intervals else 30
            next_date = (dates[-1] + timedelta(days=avg_interval)).strftime("%d/%m/%Y")
            alerts.append({
                "equipment": equipment,
                "message": f"{recent} interventions en 30j — prochaine estimée le {next_date}",
                "next_intervention": next_date,
                "severity": "high" if recent >= 5 else "medium",
            })

    # Trier par risque
    at_risk.sort(key=lambda x: x["trend_pct"], reverse=True)
    alerts.sort(key=lambda x: x["severity"])

    return {"alerts": alerts[:5], "at_risk": at_risk[:5]}
