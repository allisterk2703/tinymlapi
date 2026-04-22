import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services import predict

logger = logging.getLogger(__name__)

router = APIRouter()


class InvocationRequest(BaseModel):
    min_val: int
    max_val: int


@router.get("/")
def index():
    return {"service": "tinymlapi", "framework": "fastapi", "endpoints": ["/health", "/invocations"]}


@router.get("/health")
def health():
    logger.info("GET /health")
    response = {"status": "ok"}
    logger.info("Response: %s", response)
    return response


@router.post("/invocations")
def invocations(payload: InvocationRequest):
    logger.info("POST /invocations - payload: %s", payload)

    if payload.min_val > payload.max_val:
        raise HTTPException(status_code=400, detail="'min_val' must be less than or equal to 'max_val'.")

    result = predict(payload.min_val, payload.max_val)
    logger.info("Response: %s", result)
    return result
