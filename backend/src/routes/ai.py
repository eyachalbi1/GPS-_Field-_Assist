from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from src.services.pdf_ai_service import answer, build_index, search
from src.services.ai_diagnostic_service import get_recommendations, get_predictive_alerts
from src.services.recommendation_service import get_task_recommendations

router = APIRouter()


class QuestionRequest(BaseModel):
    question: str
    top_k: int = 5


@router.post("/ask")
async def ask(req: QuestionRequest):
    if not req.question.strip():
        raise HTTPException(status_code=400, detail="Question vide")
    return answer(req.question)


@router.get("/search")
async def search_docs(q: str, top_k: int = 5):
    if not q.strip():
        raise HTTPException(status_code=400, detail="Requête vide")
    return {"results": search(q, top_k)}


@router.post("/index")
async def reindex():
    """Rebuild the PDF index (call after uploading new PDFs)."""
    try:
        build_index()
        return {"status": "ok", "message": "Index reconstruit"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


class RecommendationRequest(BaseModel):
    equipment_type: str = ""
    symptom: str = ""

@router.post("/recommendations")
async def recommendations(req: RecommendationRequest):
    return get_recommendations(req.equipment_type, req.symptom)

@router.get("/predictive")
async def predictive():
    return get_predictive_alerts()


class TaskRecommendationRequest(BaseModel):
    name: str = ""
    description: str = ""

@router.post("/task-recommendations")
async def task_recommendations(req: TaskRecommendationRequest):
    return get_task_recommendations(req.name, req.description)
