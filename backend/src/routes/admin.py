from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from src.services.auth_service import get_current_user
from src.models.database import get_db, hash_password

router = APIRouter()


def require_admin(current_user: dict = Depends(get_current_user)):
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Accès réservé aux administrateurs")
    return current_user


class CreateTechnicianRequest(BaseModel):
    username: str
    password: str


class UpdateUsernameRequest(BaseModel):
    new_username: str


class UpdateUserIdRequest(BaseModel):
    new_user_id: str


class CreateTaskRequest(BaseModel):
    id: int | None = None
    subject: str
    description: str = ""
    stage: str = "nouveau"
    created_at: str = ""
    partner_name: str = ""
    start_time: str = ""
    end_time: str = ""


@router.get("/technicians")
async def list_technicians(admin=Depends(require_admin)):
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, assigned_to_name AS username, role, date_de_creation, assigned_to_id
                FROM users WHERE role = 'technicien'
                ORDER BY date_de_creation DESC
            """)
            users = [dict(r) for r in cur.fetchall()]
            conn.commit()
    return {"technicians": users, "total": len(users)}


@router.post("/technicians")
async def create_technician(req: CreateTechnicianRequest, admin=Depends(require_admin)):
    if len(req.username) > 20:
        raise HTTPException(status_code=400, detail="Username max 20 caractères")
    if len(req.password) < 4:
        raise HTTPException(status_code=400, detail="Mot de passe min 4 caractères")
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM users WHERE assigned_to_name = %s", (req.username,))
            if cur.fetchone():
                raise HTTPException(status_code=409, detail="Username déjà utilisé")
            cur.execute(
                "INSERT INTO users (assigned_to_name, password, role) VALUES (%s, %s, 'technicien') RETURNING id",
                (req.username, hash_password(req.password))
            )
            new_id = cur.fetchone()["id"]
            conn.commit()
    return {"message": "Technicien créé", "id": new_id, "username": req.username}


@router.delete("/technicians/{user_id}")
async def delete_technician(user_id: int, admin=Depends(require_admin)):
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT role FROM users WHERE id = %s", (user_id,))
            user = cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="Utilisateur introuvable")
            if user["role"] == "admin":
                raise HTTPException(status_code=403, detail="Impossible de supprimer un admin")
            cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
            conn.commit()
    return {"message": "Technicien supprimé"}


@router.put("/technicians/{user_id}/username")
async def update_username(user_id: int, req: UpdateUsernameRequest, admin=Depends(require_admin)):
    if len(req.new_username) > 20:
        raise HTTPException(status_code=400, detail="Username max 20 caractères")
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM users WHERE assigned_to_name = %s AND id != %s", (req.new_username, user_id))
            if cur.fetchone():
                raise HTTPException(status_code=409, detail="Username déjà utilisé")
            cur.execute("UPDATE users SET assigned_to_name = %s WHERE id = %s AND role = 'technicien'",
                        (req.new_username, user_id))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Technicien introuvable")
            conn.commit()
    return {"message": "Username mis à jour", "new_username": req.new_username}


@router.put("/technicians/{user_id}/odoo-id")
async def update_odoo_id(user_id: int, req: UpdateUserIdRequest, admin=Depends(require_admin)):
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE users SET assigned_to_id = %s WHERE id = %s AND role = 'technicien'",
                (req.new_user_id.strip(), user_id)
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Technicien introuvable")
            conn.commit()
    return {"message": "assigned_to_id mis à jour", "assigned_to_id": req.new_user_id}


@router.get("/technicians/{user_id}/tasks")
async def get_technician_tasks(user_id: int, admin=Depends(require_admin)):
    # Récupérer l'odoo_id du technicien pour matcher les tâches Odoo
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT assigned_to_id FROM users WHERE id = %s", (user_id,))
            row = cur.fetchone()
            odoo_id = row['assigned_to_id'] if row else None

    # 1. Tâches depuis l'API Odoo filtrées par assigned_to_id
    import requests as req
    odoo_tasks = []
    if odoo_id:
        try:
            r = req.get('http://41.226.24.13:5000/api/helpdesk/tasks', timeout=8)
            if r.status_code == 200:
                all_odoo = r.json()
                odoo_tasks = [
                    t for t in all_odoo
                    if str(t.get('assigned_to_id', '')) == str(odoo_id)
                ]
        except Exception:
            pass

    if odoo_tasks:
        # Fusionner Odoo + local (sans doublons)
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT t.id,
                           COALESCE(t.subject, '')     AS subject,
                           COALESCE(t.description, '') AS description,
                           COALESCE(t.partner_name, '') AS partner_name,
                           COALESCE(t.start_time, '')  AS start_time,
                           COALESCE(t.end_time, '')    AS end_time,
                           COALESCE(t.stage, 'nouveau') AS stage,
                           COALESCE(t.assigned_to, u.assigned_to_name, '') AS assigned_to,
                           t.created_at
                    FROM tasks t
                    LEFT JOIN users u ON u.id::text = t.assigned_to_id
                    WHERE t.assigned_to_id = %s::text
                    ORDER BY t.created_at DESC
                """, (str(user_id),))
                local_tasks = [dict(r) for r in cur.fetchall()]
        odoo_ids = {str(t.get('id')) for t in odoo_tasks}
        extra_local = [t for t in local_tasks if str(t['id']) not in odoo_ids]
        return {"tasks": extra_local + odoo_tasks}

    # 2. Fallback : tâches locales
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT t.id,
                       COALESCE(t.subject, '')    AS subject,
                       COALESCE(t.description, '') AS description,
                       COALESCE(t.partner_name, '') AS partner_name,
                       COALESCE(t.start_time, '')  AS start_time,
                       COALESCE(t.end_time, '')    AS end_time,
                       COALESCE(t.stage, 'nouveau') AS stage,
                       COALESCE(t.assigned_to, u.assigned_to_name, '') AS assigned_to,
                       t.created_at
                FROM tasks t
                LEFT JOIN users u ON u.id::text = t.assigned_to_id
                WHERE t.assigned_to_id = %s::text
                   OR t.assigned_to_id = %s::text
                ORDER BY t.created_at DESC
            """, (str(user_id), str(odoo_id) if odoo_id else str(user_id)))
            tasks = [dict(r) for r in cur.fetchall()]
    return {"tasks": tasks}


@router.post("/technicians/{user_id}/tasks")
async def create_task(user_id: int, req: CreateTaskRequest, admin=Depends(require_admin)):
    from datetime import datetime
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, assigned_to_name FROM users WHERE id = %s AND role = 'technicien'", (user_id,))
            tech = cur.fetchone()
            if not tech:
                raise HTTPException(status_code=404, detail="Technicien introuvable")
            created_at = req.created_at or datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            if req.id is not None:
                cur.execute("""
                    INSERT INTO tasks (id, subject, description, partner_name,
                                       start_time, end_time, stage, assigned_to_id, assigned_to, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
                """, (req.id, req.subject, req.description, req.partner_name,
                      req.start_time, req.end_time, req.stage,
                      str(user_id), tech['assigned_to_name'], created_at))
            else:
                cur.execute("""
                    INSERT INTO tasks (subject, description, partner_name,
                                       start_time, end_time, stage, assigned_to_id, assigned_to, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
                """, (req.subject, req.description, req.partner_name,
                      req.start_time, req.end_time, req.stage,
                      str(user_id), tech['assigned_to_name'], created_at))
            new_id = cur.fetchone()["id"]
            conn.commit()
    return {"message": "Tâche créée", "id": new_id, "subject": req.subject,
            "stage": req.stage, "created_at": created_at, "description": req.description}


@router.get("/dashboard")
async def get_dashboard(admin=Depends(require_admin)):
    from datetime import datetime, timedelta
    import requests as req
    now         = datetime.now()
    day_start   = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start  = day_start - timedelta(days=now.weekday())
    month_start = day_start.replace(day=1)

    # Techniciens depuis la DB locale
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, assigned_to_name AS username, assigned_to_id FROM users WHERE role = 'technicien'")
            techs = [dict(r) for r in cur.fetchall()]

    # Tâches depuis l'API Odoo helpdesk (source principale)
    all_tasks = []
    try:
        r = req.get('http://41.226.24.13:5000/api/helpdesk/tasks', timeout=8)
        if r.status_code == 200:
            all_tasks = r.json()
    except Exception:
        pass

    # Fallback DB locale si Odoo injoignable
    if not all_tasks:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT t.id, t.assigned_to_id AS user_id,
                           COALESCE(t.stage, t.status, 'a_faire') AS status,
                           t.start_time, t.end_time,
                           COALESCE(t.subject, t.name, '') AS name,
                           t.created_at
                    FROM tasks t
                """)
                all_tasks = [dict(r) for r in cur.fetchall()]

    done_statuses = {'termine', 'done', 'completed', 'Done', 'Cancelled'}
    # Note: on ne compte pas Cancelled comme done pour les stats
    completed_statuses = {'termine', 'done', 'completed', 'Done'}

    def parse_min(v):
        if not v: return None
        v = str(v).strip()
        try:
            if 'h' in v:
                p = v.replace('h', ':').split(':')
                return int(p[0]) * 60 + (int(p[1]) if len(p) > 1 and p[1] else 0)
            if ':' in v:
                p = v.split(':')
                return int(p[0]) * 60 + int(p[1])
        except Exception:
            pass
        return None

    def task_in_period(t, since):
        ca = t.get('created_at')
        if not ca: return False
        try:
            dt = ca if isinstance(ca, datetime) else datetime.fromisoformat(str(ca).replace('Z', ''))
            return dt >= since
        except Exception:
            return False

    def period_stats(tasks_subset):
        done = [t for t in tasks_subset if (t.get('status') or t.get('stage', '')) in completed_statuses]
        durs = []
        for t in done:
            s = parse_min(t.get('start_time'))
            e = parse_min(t.get('end_time'))
            if s is not None and e is not None and e > s:
                durs.append(e - s)
        return {
            'done':    len(done),
            'total':   len(tasks_subset),
            'avg_min': round(sum(durs) / len(durs)) if durs else None,
        }

    global_periods = {
        'day':   period_stats([t for t in all_tasks if task_in_period(t, day_start)]),
        'week':  period_stats([t for t in all_tasks if task_in_period(t, week_start)]),
        'month': period_stats([t for t in all_tasks if task_in_period(t, month_start)]),
        'all':   period_stats(all_tasks),
    }

    all_durations = []
    tech_stats    = []
    for tech in techs:
        tid      = tech['id']
        odoo_id  = tech.get('assigned_to_id')
        # Matcher par assigned_to_id Odoo ou user_id local
        tasks = [
            t for t in all_tasks
            if (odoo_id and (t.get('assigned_to_id') == odoo_id or
                             str(t.get('assigned_to_id', '')) == str(odoo_id)))
            or t.get('user_id') == tid
        ]
        status_field = lambda t: t.get('status') or t.get('stage', '')
        done  = [t for t in tasks if status_field(t) in completed_statuses]
        durs  = []
        for t in tasks:
            s = parse_min(t.get('start_time'))
            e = parse_min(t.get('end_time'))
            if s is not None and e is not None and e > s:
                durs.append(e - s)
        all_durations.extend(durs)
        avg = round(sum(durs) / len(durs)) if durs else None

        comp_score = (len(done) / len(tasks) * 5) if tasks else 0
        reg_score  = 5.0
        if len(durs) >= 2:
            mean = sum(durs) / len(durs)
            cv   = (sum((d - mean) ** 2 for d in durs) / len(durs)) ** 0.5 / mean if mean else 1
            reg_score = max(0, 5 - cv * 5)
        score = round(min(comp_score * 0.4 + reg_score * 0.6, 5.0), 1)

        tech_stats.append({
            'id':               tid,
            'username':         tech['username'],
            'total_tasks':      len(tasks),
            'completed_tasks':  len(done),
            'avg_duration_min': avg,
            'score':            score,
            'periods': {
                'day':   period_stats([t for t in tasks if task_in_period(t, day_start)]),
                'week':  period_stats([t for t in tasks if task_in_period(t, week_start)]),
                'month': period_stats([t for t in tasks if task_in_period(t, month_start)]),
            },
        })

    tech_stats.sort(key=lambda x: x['score'], reverse=True)
    global_avg = round(sum(all_durations) / len(all_durations)) if all_durations else None
    total_done = sum(1 for t in all_tasks if (t.get('status') or t.get('stage', '')) in completed_statuses)

    return {
        'total_technicians':       len(techs),
        'total_tasks':             len(all_tasks),
        'completed_tasks':         total_done,
        'pending_tasks':           len(all_tasks) - total_done,
        'global_avg_duration_min': global_avg,
        'periods':                 global_periods,
        'technicians':             tech_stats,
    }


@router.get("/activity-feed")
async def get_activity_feed(admin=Depends(require_admin)):
    from datetime import datetime, timedelta
    import requests as req

    now = datetime.now()
    since = now - timedelta(hours=48)
    completed_statuses = {'termine', 'done', 'completed', 'Done'}
    events = []

    # Techniciens
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, assigned_to_name AS username, assigned_to_id FROM users WHERE role = 'technicien'")
            techs = {str(r['id']): r for r in cur.fetchall()}
            odoo_map = {str(r['assigned_to_id']): r for r in techs.values() if r.get('assigned_to_id')}

    # Tâches Odoo
    all_tasks = []
    try:
        r = req.get('http://41.226.24.13:5000/api/helpdesk/tasks', timeout=8)
        if r.status_code == 200:
            all_tasks = r.json()
    except Exception:
        pass

    if not all_tasks:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT id, assigned_to_id, COALESCE(stage,'nouveau') AS status,
                           COALESCE(subject,'') AS name, created_at
                    FROM tasks ORDER BY created_at DESC LIMIT 100
                """)
                all_tasks = [dict(r) for r in cur.fetchall()]

    def resolve_name(t):
        aid = str(t.get('assigned_to_id') or '')
        tech = odoo_map.get(aid) or techs.get(aid)
        return tech['username'] if tech else (t.get('assigned_to') or 'Technicien')

    def parse_dt(v):
        if not v: return None
        try:
            return v if isinstance(v, datetime) else datetime.fromisoformat(str(v).replace('Z', ''))
        except Exception:
            return None

    # Événements : tâches terminées récentes
    for t in all_tasks:
        status = t.get('status') or t.get('stage', '')
        if status not in completed_statuses:
            continue
        dt = parse_dt(t.get('created_at'))
        if dt and dt >= since:
            name = t.get('name') or t.get('subject') or 'Tâche'
            events.append({
                'type': 'task_done',
                'icon': 'check_circle',
                'color': '#26C6A6',
                'message': f"{resolve_name(t)} a terminé « {name[:40]} »",
                'ts': dt.isoformat(),
            })

    # Événements : nouvelles tâches assignées (status != done)
    new_tasks = [t for t in all_tasks
                 if (t.get('status') or t.get('stage', '')) not in completed_statuses]
    for t in new_tasks:
        dt = parse_dt(t.get('created_at'))
        if dt and dt >= since:
            name = t.get('name') or t.get('subject') or 'Tâche'
            events.append({
                'type': 'task_new',
                'icon': 'assignment',
                'color': '#5DA5B3',
                'message': f"Nouvelle tâche assignée à {resolve_name(t)} : « {name[:40]} »",
                'ts': dt.isoformat(),
            })

    # Événements : techniciens avec score élevé (score >= 4)
    tech_list = list(techs.values())
    for tech in tech_list:
        tid = tech['id']
        odoo_id = tech.get('assigned_to_id')
        tasks = [
            t for t in all_tasks
            if (odoo_id and str(t.get('assigned_to_id', '')) == str(odoo_id))
            or str(t.get('assigned_to_id', '')) == str(tid)
        ]
        done = [t for t in tasks if (t.get('status') or t.get('stage', '')) in completed_statuses]
        if len(tasks) >= 3:
            score = round((len(done) / len(tasks)) * 5, 1)
            if score >= 4.0:
                events.append({
                    'type': 'score_high',
                    'icon': 'star',
                    'color': '#FFB347',
                    'message': f"Score de {tech['username']} : {score}/5 ⭐",
                    'ts': now.isoformat(),
                })

    # Trier par date décroissante, limiter à 20
    events.sort(key=lambda e: e['ts'], reverse=True)
    return events[:20]


@router.get("/live-insights")
async def get_live_insights(admin=Depends(require_admin)):
    """
    Génère des insights AI en temps réel pour le dashboard admin :
    - Anomalies de performance détectées
    - Techniciens sous-performants / surperformants
    - Alertes prédictives de maintenance
    - Recommandations d'actions immédiates
    """
    from datetime import datetime, timedelta
    from src.services.ai_diagnostic_service import get_predictive_alerts
    import requests as req_lib

    now = datetime.now()
    week_start = now.replace(hour=0, minute=0, second=0) - timedelta(days=now.weekday())
    completed_statuses = {'termine', 'done', 'completed', 'Done'}

    # Techniciens
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, assigned_to_name AS username, assigned_to_id FROM users WHERE role = 'technicien'")
            techs = [dict(r) for r in cur.fetchall()]

    # Tâches
    all_tasks = []
    try:
        r = req_lib.get('http://41.226.24.13:5000/api/helpdesk/tasks', timeout=8)
        if r.status_code == 200:
            all_tasks = r.json()
    except Exception:
        pass
    if not all_tasks:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id, assigned_to_id, COALESCE(stage,'nouveau') AS status, start_time, end_time, created_at FROM tasks")
                all_tasks = [dict(r) for r in cur.fetchall()]

    def parse_min(v):
        if not v: return None
        v = str(v).strip()
        try:
            if 'h' in v:
                p = v.replace('h', ':').split(':')
                return int(p[0]) * 60 + (int(p[1]) if len(p) > 1 and p[1] else 0)
            if ':' in v:
                p = v.split(':')
                return int(p[0]) * 60 + int(p[1])
        except Exception:
            pass
        return None

    def task_in_period(t, since):
        ca = t.get('created_at')
        if not ca: return False
        try:
            dt = ca if isinstance(ca, datetime) else datetime.fromisoformat(str(ca).replace('Z', ''))
            return dt >= since
        except Exception:
            return False

    insights = []
    anomalies = []
    recommendations = []

    # ── Analyse par technicien ──
    tech_week_stats = []
    for tech in techs:
        tid = tech['id']
        odoo_id = tech.get('assigned_to_id')
        tasks = [
            t for t in all_tasks
            if (odoo_id and str(t.get('assigned_to_id', '')) == str(odoo_id))
            or str(t.get('assigned_to_id', '')) == str(tid)
        ]
        week_tasks = [t for t in tasks if task_in_period(t, week_start)]
        done_week = [t for t in week_tasks if (t.get('status') or t.get('stage', '')) in completed_statuses]
        durs = []
        for t in tasks:
            s = parse_min(t.get('start_time'))
            e = parse_min(t.get('end_time'))
            if s is not None and e is not None and e > s:
                durs.append(e - s)
        avg = round(sum(durs) / len(durs)) if durs else None
        rate = len(done_week) / len(week_tasks) if week_tasks else None
        tech_week_stats.append({
            'username': tech['username'],
            'week_total': len(week_tasks),
            'week_done': len(done_week),
            'rate': rate,
            'avg_min': avg,
        })

    # ── Anomalie : taux de complétion < 30% cette semaine ──
    low_perf = [t for t in tech_week_stats if t['rate'] is not None and t['rate'] < 0.3 and t['week_total'] >= 2]
    for t in low_perf:
        anomalies.append({
            'type': 'low_completion',
            'severity': 'high',
            'icon': 'warning',
            'color': '#FF4444',
            'title': f"Faible complétion — {t['username']}",
            'message': f"{t['username']} : {t['week_done']}/{t['week_total']} tâches terminées cette semaine ({round((t['rate'] or 0)*100)}%)",
        })

    # ── Anomalie : durée moyenne anormalement élevée (> 3h) ──
    slow_techs = [t for t in tech_week_stats if t['avg_min'] is not None and t['avg_min'] > 180]
    for t in slow_techs:
        h = t['avg_min'] // 60
        m = t['avg_min'] % 60
        anomalies.append({
            'type': 'slow_duration',
            'severity': 'medium',
            'icon': 'timer',
            'color': '#FFB347',
            'title': f"Durée élevée — {t['username']}",
            'message': f"{t['username']} : durée moyenne {h}h{m if m else ''}min — intervention complexe ou blocage détecté",
        })

    # ── Insight positif : top performer ──
    top = [t for t in tech_week_stats if t['rate'] is not None and t['rate'] >= 0.8 and t['week_total'] >= 3]
    for t in top:
        insights.append({
            'type': 'top_performer',
            'severity': 'info',
            'icon': 'star',
            'color': '#26C6A6',
            'title': f"Top performer — {t['username']}",
            'message': f"{t['username']} : {round((t['rate'] or 0)*100)}% de complétion cette semaine ✓",
        })

    # ── Recommandation : technicien sans tâche cette semaine ──
    idle = [t for t in tech_week_stats if t['week_total'] == 0]
    if idle:
        names = ', '.join(t['username'] for t in idle[:3])
        recommendations.append({
            'type': 'idle_technician',
            'severity': 'info',
            'icon': 'person_off',
            'color': '#5DA5B3',
            'title': 'Techniciens sans tâche',
            'message': f"{names} n'ont aucune tâche assignée cette semaine — redistribution recommandée",
        })

    # ── Alertes prédictives depuis le service AI ──
    try:
        pred = get_predictive_alerts()
        for alert in pred.get('alerts', [])[:2]:
            recommendations.append({
                'type': 'predictive',
                'severity': 'medium',
                'icon': 'build',
                'color': '#FFB347',
                'title': 'Maintenance prédictive',
                'message': alert['message'],
            })
        for risk in pred.get('at_risk', [])[:2]:
            anomalies.append({
                'type': 'at_risk',
                'severity': 'high' if risk['risk'] == 'élevé' else 'medium',
                'icon': 'device_unknown',
                'color': '#FF6B35',
                'title': f"Équipement à risque — {risk['equipment'][:30]}",
                'message': f"{risk['equipment'][:40]} : +{risk['trend_pct']}% d'interventions vs période précédente",
            })
    except Exception:
        pass

    # ── Insight global : charge de travail ──
    week_all = [t for t in all_tasks if task_in_period(t, week_start)]
    week_done_all = [t for t in week_all if (t.get('status') or t.get('stage', '')) in completed_statuses]
    if week_all:
        global_rate = len(week_done_all) / len(week_all)
        if global_rate < 0.5:
            anomalies.append({
                'type': 'global_low',
                'severity': 'high',
                'icon': 'trending_down',
                'color': '#FF4444',
                'title': 'Taux global faible',
                'message': f"Seulement {round(global_rate*100)}% des tâches terminées cette semaine ({len(week_done_all)}/{len(week_all)})",
            })
        elif global_rate >= 0.8:
            insights.append({
                'type': 'global_high',
                'severity': 'info',
                'icon': 'trending_up',
                'color': '#26C6A6',
                'title': 'Excellente semaine',
                'message': f"{round(global_rate*100)}% des tâches terminées cette semaine — performance optimale ✓",
            })

    return {
        'generated_at': now.isoformat(),
        'anomalies': anomalies[:5],
        'insights': insights[:3],
        'recommendations': recommendations[:3],
        'summary': {
            'total_anomalies': len(anomalies),
            'total_insights': len(insights),
            'week_completion_rate': round(len(week_done_all) / len(week_all) * 100) if week_all else 0,
        },
    }


@router.delete("/technicians/{user_id}/tasks/{task_id}")
async def delete_task(user_id: int, task_id: int, admin=Depends(require_admin)):
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM tasks WHERE id = %s AND assigned_to_id = %s", (task_id, user_id))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Tâche introuvable")
            conn.commit()
    return {"message": "Tâche supprimée"}


@router.get("/technicians/{user_id}/performance")
async def get_technician_performance(user_id: int, admin=Depends(require_admin)):
    # Récupérer odoo_id
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT assigned_to_id FROM users WHERE id = %s", (user_id,))
            row = cur.fetchone()
            odoo_id = row['assigned_to_id'] if row else None

    # Tâches Odoo si disponibles
    import requests as req_lib
    tasks_raw = []
    if odoo_id:
        try:
            r = req_lib.get('http://41.226.24.13:5000/api/helpdesk/tasks', timeout=8)
            if r.status_code == 200:
                tasks_raw = [t for t in r.json() if str(t.get('assigned_to_id', '')) == str(odoo_id)]
        except Exception:
            pass

    # Fallback local
    if not tasks_raw:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT id, COALESCE(subject, '') AS name,
                           start_time, end_time,
                           COALESCE(stage, 'nouveau') AS status,
                           created_at
                    FROM tasks
                    WHERE assigned_to_id = %s::text OR assigned_to_id = %s::text
                    ORDER BY created_at DESC
                """, (str(user_id), str(odoo_id) if odoo_id else str(user_id)))
                tasks_raw = [dict(r) for r in cur.fetchall()]

    def parse_minutes(v):
        if not v: return None
        v = str(v).strip()
        try:
            if 'h' in v:
                parts = v.replace('h', ':').split(':')
                return int(parts[0]) * 60 + (int(parts[1]) if len(parts) > 1 and parts[1] else 0)
            if ':' in v:
                p = v.split(':')
                return int(p[0]) * 60 + int(p[1])
        except Exception:
            pass
        return None

    done_statuses = {'termine', 'done', 'completed', 'Done'}
    task_stats = []
    durations  = []

    for t in tasks_raw:
        name  = t.get('name') or t.get('subject') or ''
        stage = t.get('status') or t.get('stage') or 'nouveau'
        start = parse_minutes(t.get('start_time'))
        end   = parse_minutes(t.get('end_time'))
        duration_min = None
        if start is not None and end is not None and end > start:
            duration_min = end - start
            durations.append(duration_min)
        task_stats.append({
            'id':           t.get('id'),
            'name':         name,
            'status':       stage,
            'start_time':   t.get('start_time') or '',
            'end_time':     t.get('end_time') or '',
            'duration_min': duration_min,
            'created_at':   str(t.get('created_at') or ''),
        })

    total     = len(task_stats)
    completed = sum(1 for t in task_stats if t['status'] in done_statuses)
    avg_dur   = round(sum(durations) / len(durations)) if durations else None

    completion_score = (completed / total * 5) if total > 0 else 0
    regularity_score = 5.0
    if len(durations) >= 2:
        mean     = sum(durations) / len(durations)
        variance = sum((d - mean) ** 2 for d in durations) / len(durations)
        cv       = (variance ** 0.5) / mean if mean > 0 else 1
        regularity_score = max(0, 5 - cv * 5)
    score = round(completion_score * 0.4 + regularity_score * 0.6, 1)

    return {
        'tasks':            task_stats,
        'total_tasks':      total,
        'completed_tasks':  completed,
        'avg_duration_min': avg_dur,
        'score':            min(score, 5.0),
    }