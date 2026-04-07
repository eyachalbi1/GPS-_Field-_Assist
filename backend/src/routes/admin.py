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
    reference: str
    name: str
    description: str = ""
    partner_name: str = ""
    start_time: str = ""
    end_time: str = ""


@router.get("/technicians")
async def list_technicians(admin=Depends(require_admin)):
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                ALTER TABLE users ADD COLUMN IF NOT EXISTS odoo_user_id VARCHAR(50)
            """)
            cur.execute("""
                SELECT id, username, role, date_de_creation, odoo_user_id
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
            cur.execute("SELECT id FROM users WHERE username = %s", (req.username,))
            if cur.fetchone():
                raise HTTPException(status_code=409, detail="Username déjà utilisé")
            cur.execute(
                "INSERT INTO users (username, password, role) VALUES (%s, %s, 'technicien') RETURNING id",
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
            cur.execute("SELECT id FROM users WHERE username = %s AND id != %s", (req.new_username, user_id))
            if cur.fetchone():
                raise HTTPException(status_code=409, detail="Username déjà utilisé")
            cur.execute("UPDATE users SET username = %s WHERE id = %s AND role = 'technicien'",
                        (req.new_username, user_id))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Technicien introuvable")
            conn.commit()
    return {"message": "Username mis à jour", "new_username": req.new_username}


@router.put("/technicians/{user_id}/odoo-id")
async def update_odoo_id(user_id: int, req: UpdateUserIdRequest, admin=Depends(require_admin)):
    """Mettre à jour l'identifiant Odoo/externe du technicien."""
    with get_db() as conn:
        with conn.cursor() as cur:
            # Ajouter la colonne si elle n'existe pas
            cur.execute("""
                ALTER TABLE users ADD COLUMN IF NOT EXISTS odoo_user_id VARCHAR(50)
            """)
            cur.execute(
                "UPDATE users SET odoo_user_id = %s WHERE id = %s AND role = 'technicien'",
                (req.new_user_id.strip(), user_id)
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Technicien introuvable")
            conn.commit()
    return {"message": "User ID mis à jour", "odoo_user_id": req.new_user_id}


@router.get("/technicians/{user_id}/tasks")
async def get_technician_tasks(user_id: int, admin=Depends(require_admin)):
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, reference, name, description, partner_name,
                       start_time, end_time, status, created_at
                FROM tasks WHERE user_id = %s ORDER BY created_at DESC
            """, (user_id,))
            tasks = [dict(r) for r in cur.fetchall()]
    return {"tasks": tasks}


@router.post("/technicians/{user_id}/tasks")
async def create_task(user_id: int, req: CreateTaskRequest, admin=Depends(require_admin)):
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM users WHERE id = %s AND role = 'technicien'", (user_id,))
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Technicien introuvable")
            cur.execute("SELECT id FROM tasks WHERE reference = %s", (req.reference,))
            if cur.fetchone():
                raise HTTPException(status_code=409, detail="Référence déjà utilisée")
            cur.execute("""
                INSERT INTO tasks (reference, name, description, partner_name,
                                   start_time, end_time, status, user_id)
                VALUES (%s,%s,%s,%s,%s,%s,'a_faire',%s) RETURNING id
            """, (req.reference, req.name, req.description,
                  req.partner_name, req.start_time, req.end_time, user_id))
            new_id = cur.fetchone()["id"]
            conn.commit()
    return {"message": "Tâche créée", "id": new_id}


@router.get("/dashboard")
async def get_dashboard(admin=Depends(require_admin)):
    from datetime import datetime, timedelta
    now = datetime.now()
    day_start   = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start  = day_start - timedelta(days=now.weekday())
    month_start = day_start.replace(day=1)

    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, username FROM users WHERE role = 'technicien'")
            techs = [dict(r) for r in cur.fetchall()]
            cur.execute("""
                SELECT t.id, t.user_id, t.status, t.start_time, t.end_time,
                       t.name, t.created_at, u.username
                FROM tasks t JOIN users u ON u.id = t.user_id
            """)
            all_tasks = [dict(r) for r in cur.fetchall()]

    done_statuses = {'termine', 'done', 'completed'}

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
            dt = ca if isinstance(ca, datetime) else datetime.fromisoformat(str(ca).replace('Z',''))
            return dt >= since
        except Exception:
            return False

    def period_stats(tasks_subset):
        done  = [t for t in tasks_subset if t['status'] in done_statuses]
        durs  = []
        for t in done:
            s = parse_min(t['start_time'])
            e = parse_min(t['end_time'])
            if s is not None and e is not None and e > s:
                durs.append(e - s)
        return {
            'done':     len(done),
            'total':    len(tasks_subset),
            'avg_min':  round(sum(durs) / len(durs)) if durs else None,
        }

    # Stats globales par période
    global_periods = {
        'day':   period_stats([t for t in all_tasks if task_in_period(t, day_start)]),
        'week':  period_stats([t for t in all_tasks if task_in_period(t, week_start)]),
        'month': period_stats([t for t in all_tasks if task_in_period(t, month_start)]),
        'all':   period_stats(all_tasks),
    }

    # Stats par technicien
    all_durations = []
    tech_stats = []
    for tech in techs:
        tid   = tech['id']
        tasks = [t for t in all_tasks if t['user_id'] == tid]
        done  = [t for t in tasks if t['status'] in done_statuses]
        durs  = []
        for t in tasks:
            s = parse_min(t['start_time'])
            e = parse_min(t['end_time'])
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

    return {
        'total_technicians':      len(techs),
        'total_tasks':            len(all_tasks),
        'completed_tasks':        sum(1 for t in all_tasks if t['status'] in done_statuses),
        'pending_tasks':          sum(1 for t in all_tasks if t['status'] not in done_statuses),
        'global_avg_duration_min': global_avg,
        'periods':                global_periods,
        'technicians':            tech_stats,
    }


@router.delete("/technicians/{user_id}/tasks/{task_id}")
async def delete_task(user_id: int, task_id: int, admin=Depends(require_admin)):
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM tasks WHERE id = %s AND user_id = %s", (task_id, user_id))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Tâche introuvable")
            conn.commit()
    return {"message": "Tâche supprimée"}


@router.get("/technicians/{user_id}/performance")
async def get_technician_performance(user_id: int, admin=Depends(require_admin)):
    """
    Retourne pour chaque tâche terminée la durée réelle (start_time → end_time)
    et un score global d'évaluation du technicien.
    """
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, reference, name, start_time, end_time, status, created_at
                FROM tasks
                WHERE user_id = %s
                ORDER BY created_at DESC
            """, (user_id,))
            tasks = [dict(r) for r in cur.fetchall()]

    def parse_minutes(t):
        if not t:
            return None
        t = str(t).strip()
        try:
            if 'h' in t:
                parts = t.replace('h', ':').split(':')
                return int(parts[0]) * 60 + (int(parts[1]) if len(parts) > 1 and parts[1] else 0)
            if ':' in t:
                p = t.split(':')
                return int(p[0]) * 60 + int(p[1])
        except Exception:
            pass
        return None

    task_stats = []
    durations = []

    for t in tasks:
        start = parse_minutes(t['start_time'])
        end   = parse_minutes(t['end_time'])
        duration_min = None
        if start is not None and end is not None and end > start:
            duration_min = end - start
            durations.append(duration_min)

        task_stats.append({
            'id':           t['id'],
            'reference':    t['reference'],
            'name':         t['name'],
            'status':       t['status'],
            'start_time':   t['start_time'],
            'end_time':     t['end_time'],
            'duration_min': duration_min,
            'created_at':   str(t['created_at']) if t['created_at'] else '',
        })

    total      = len(tasks)
    completed  = sum(1 for t in tasks if t['status'] in ('termine', 'done', 'completed'))
    avg_dur    = round(sum(durations) / len(durations)) if durations else None

    # Score sur 5 : taux de complétion (40%) + régularité durée (60%)
    completion_score = (completed / total * 5) if total > 0 else 0
    regularity_score = 5.0
    if len(durations) >= 2:
        mean = sum(durations) / len(durations)
        variance = sum((d - mean) ** 2 for d in durations) / len(durations)
        cv = (variance ** 0.5) / mean if mean > 0 else 1
        regularity_score = max(0, 5 - cv * 5)

    score = round(completion_score * 0.4 + regularity_score * 0.6, 1)

    return {
        'tasks':           task_stats,
        'total_tasks':     total,
        'completed_tasks': completed,
        'avg_duration_min': avg_dur,
        'score':           min(score, 5.0),
    }
