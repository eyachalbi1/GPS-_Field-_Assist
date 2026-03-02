from fastapi import APIRouter, HTTPException, Depends
from typing import List
from ..models.schemas import TaskResponse
from ..controllers.task_controller import get_all_tasks, get_task_by_id, update_task_status
from ..services.auth_service import get_current_user

router = APIRouter()

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