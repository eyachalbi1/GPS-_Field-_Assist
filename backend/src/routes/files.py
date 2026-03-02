from fastapi import APIRouter, UploadFile, File, HTTPException, Request
from typing import List
import os
from uuid import uuid4

router = APIRouter()

UPLOAD_FOLDER = os.path.join(os.getcwd(), 'static', 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


@router.post('/upload')
async def upload_files(files: List[UploadFile] = File(...), request: Request = None, task_id: str | None = None):
    """Upload files. If `task_id` provided, save under static/uploads/tasks/<task_id>/
    Returns list of public URLs under /uploads/..."""
    saved_urls = []
    # choose folder
    target_folder = UPLOAD_FOLDER
    if task_id:
        target_folder = os.path.join(UPLOAD_FOLDER, 'tasks', task_id)
    os.makedirs(target_folder, exist_ok=True)

    for f in files:
        try:
            ext = os.path.splitext(f.filename)[1]
            filename = f"{uuid4().hex}{ext}"
            dest_path = os.path.join(target_folder, filename)
            content = await f.read()
            with open(dest_path, 'wb') as fp:
                fp.write(content)

            # If saved under tasks, return /uploads/tasks/<task_id>/<filename>
            rel_parts = []
            # compute public path relative to /uploads
            if task_id:
                rel_parts = ['uploads', 'tasks', task_id, filename]
            else:
                rel_parts = ['uploads', filename]

            saved_urls.append('/' + '/'.join(rel_parts))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Erreur lors de l'upload: {str(e)}")

    return {"files": saved_urls}



@router.get('/task/{task_id}/media')
async def list_task_media(task_id: str):
    folder = os.path.join(UPLOAD_FOLDER, 'tasks', task_id)
    if not os.path.exists(folder):
        return {"files": []}
    files = []
    for name in os.listdir(folder):
        files.append(f"/uploads/tasks/{task_id}/{name}")
    return {"files": files}


@router.delete('/task/{task_id}/media/{filename}')
async def delete_task_media(task_id: str, filename: str):
    # sanitize filename
    if '/' in filename or '..' in filename or '\\' in filename:
        raise HTTPException(status_code=400, detail="Invalid filename")
    path = os.path.join(UPLOAD_FOLDER, 'tasks', task_id, filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="File not found")
    try:
        os.remove(path)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return {"success": True}
