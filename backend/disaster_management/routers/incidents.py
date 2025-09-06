from fastapi import APIRouter, Depends, HTTPException, status
from schemas.incident import IncidentCreate, IncidentResponse
from firebase import db
# from core.auth import get_current_user

router = APIRouter(prefix="/api/incidents", tags=["Incidents"])

@router.post("/", response_model=IncidentResponse, status_code=status.HTTP_201_CREATED)
# async def create_incident(incident: IncidentCreate, current_user: dict = Depends(get_current_user)):
async def create_incident(incident: IncidentCreate): #, current_user: dict = Depends(get_current_user)):
    if not db:
        raise HTTPException(500, "DB not connected")

    inc_ref = db.collection("incidents").document()
    inc_id = inc_ref.id

    data = incident.model_dump()
    data["incidentId"] = inc_id
    data["status"] = "Active"

    inc_ref.set(data)
    return data
