from ..models.database import get_tasks_by_user, update_task_status_db

def get_all_tasks(user_id: int):
    """Récupérer toutes les tâches d'un utilisateur"""
    return get_tasks_by_user(user_id)

def get_task_by_id(task_id: str, user_id: int):
    """Récupérer une tâche spécifique par ID"""
    tasks = get_tasks_by_user(user_id)
    for task in tasks:
        if str(task['id']) == task_id:
            return task
    return None

def update_task_status(task_id: str, status: str, user_id: int):
    """Mettre à jour le statut d'une tâche"""
    return update_task_status_db(task_id, status, user_id)