from fastapi import APIRouter, HTTPException, Depends
from typing import List
from ..models.schemas import TaskResponse
from ..controllers.task_controller import get_all_tasks, get_task_by_id, update_task_status
from ..services.auth_service import get_current_user

router = APIRouter()

from fastapi import APIRouter, HTTPException, Depends
from typing import List
from ..models.schemas import TaskResponse
from ..controllers.task_controller import get_all_tasks, get_task_by_id, update_task_status
from ..services.auth_service import get_current_user

router = APIRouter()

@router.get('/workload-prediction')
async def get_workload_prediction(current_user: dict = Depends(get_current_user)):
    """Prédit la charge de travail de la semaine prochaine pour le technicien connecté."""
    from datetime import datetime, timedelta
    import requests as req
    from ..models.database import get_db

    user_id  = current_user['id']
    username = current_user.get('username') or current_user.get('assigned_to_name', '')

    # Récupérer odoo_id
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT assigned_to_id FROM users WHERE id = %s", (user_id,))
            row = cur.fetchone()
            odoo_id = row['assigned_to_id'] if row else None

    # Tâches Odoo ou fallback local
    tasks_raw = []
    if odoo_id:
        try:
            r = req.get('http://41.226.24.13:5000/api/helpdesk/tasks', timeout=8)
            if r.status_code == 200:
                tasks_raw = [t for t in r.json()
                             if str(t.get('assigned_to_id', '')) == str(odoo_id)]
        except Exception:
            pass
    if not tasks_raw:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT id, COALESCE(subject,'') AS name, created_at,
                           COALESCE(stage,'nouveau') AS status
                    FROM tasks
                    WHERE assigned_to_id = %s::text OR assigned_to_id = %s::text
                    ORDER BY created_at DESC
                """, (str(user_id), str(odoo_id) if odoo_id else str(user_id)))
                tasks_raw = [dict(r) for r in cur.fetchall()]

    now        = datetime.now()
    completed_statuses = {'termine', 'done', 'completed', 'Done'}

    def parse_dt(v):
        if not v: return None
        try:
            return v if isinstance(v, datetime) else datetime.fromisoformat(str(v).replace('Z',''))
        except Exception:
            return None

    # Compter les tâches par semaine (8 dernières semaines)
    weekly_counts = [0] * 8
    for t in tasks_raw:
        dt = parse_dt(t.get('created_at'))
        if not dt: continue
        diff_days = (now - dt).days
        week_idx  = diff_days // 7
        if 0 <= week_idx < 8:
            weekly_counts[7 - week_idx] += 1

    # Prédiction : moyenne pondérée des 4 dernières semaines (plus récent = plus de poids)
    recent4 = weekly_counts[-4:]
    weights = [1, 2, 3, 4]
    predicted = round(sum(c * w for c, w in zip(recent4, weights)) / sum(weights))

    # Charge actuelle (semaine en cours)
    current_week = weekly_counts[-1]
    completed_total = sum(1 for t in tasks_raw
                          if (t.get('status') or t.get('stage','')) in completed_statuses)
    pending = len(tasks_raw) - completed_total

    # Tendance
    prev_week = weekly_counts[-2] if len(weekly_counts) >= 2 else 0
    if prev_week == 0:
        trend = 'stable'
        trend_pct = 0
    else:
        trend_pct = round((predicted - prev_week) / prev_week * 100)
        trend = 'hausse' if trend_pct > 10 else 'baisse' if trend_pct < -10 else 'stable'

    return {
        'username':        username,
        'current_week':    current_week,
        'predicted_next':  predicted,
        'pending_tasks':   pending,
        'completed_total': completed_total,
        'trend':           trend,
        'trend_pct':       trend_pct,
        'weekly_history':  weekly_counts,
    }


@router.get('/', response_model=List[TaskResponse])
async def get_tasks(current_user: dict = Depends(get_current_user)):
    """Récupérer toutes les tâches de l'utilisateur connecté"""
    try:
        tasks = get_all_tasks(current_user['id'])
        return tasks
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération des tâches: {str(e)}")

@router.get('/{task_id}', response_model=TaskResponse)
async def get_task(task_id: str, current_user: dict = Depends(get_current_user)):
    """Récupérer une tâche spécifique"""
    try:
        task = get_task_by_id(task_id, current_user['id'])
        if not task:
            raise HTTPException(status_code=404, detail="Tâche non trouvée")
        return task
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération de la tâche: {str(e)}")

@router.put('/{task_id}/status')
async def update_status(task_id: str, status_data: dict, current_user: dict = Depends(get_current_user)):
    """Mettre à jour le statut d'une tâche"""
    try:
        success = update_task_status(task_id, status_data['status'], current_user['id'])
        if not success:
            raise HTTPException(status_code=404, detail="Tâche non trouvée ou accès refusé")
        return {"message": "Statut mis à jour avec succès"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la mise à jour: {str(e)}")