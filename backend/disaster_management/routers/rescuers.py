# disaster_management/routers/rescuers.py

from fastapi import APIRouter, HTTPException
from firebase import db
from config import settings
from schemas.rescue import (
    RescueMemberCreate,
    RescueMemberResponse,
)

router = APIRouter(prefix="/api", tags=["Rescuers"])

# ================== Rescue Members ==================

# Create a rescue member (auto Firestore ID)
@router.post("/rescuemembers", response_model=RescueMemberResponse)
def create_rescue_member(member: RescueMemberCreate):
    ref = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document()
    data = member.dict()
    data.update({
        "id": ref.id,
        "status": "Free",
        "teamId": None, 
        "teamName": None
    })
    ref.set(data)
    return data


# Get a rescue member
@router.get("/rescuemembers/{member_id}", response_model=RescueMemberResponse)
def get_rescue_member(member_id: str):
    doc = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(member_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Rescue member not found")
    return doc.to_dict()


# List all rescue members
@router.get("/rescuemembers", response_model=list[RescueMemberResponse])
def list_rescue_members():
    members = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).stream()
    return [m.to_dict() for m in members]


# Update a rescue member
@router.put("/rescuemembers/{member_id}", response_model=RescueMemberResponse)
def update_rescue_member(member_id: str, member: RescueMemberCreate):
    ref = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(member_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Rescue member not found")
    
    update_data = member.dict()
    ref.update(update_data)
    return ref.get().to_dict()


# Delete rescue member
@router.delete("/rescuemembers/{member_id}")
def delete_rescue_member(member_id: str):
    ref = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(member_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Rescue member not found")
    ref.delete()
    return {"message": "Rescue member deleted successfully"}


# List only free rescuers not assigned to any team
@router.get("/rescuemembers/available", response_model=list[RescueMemberResponse])
def list_available_rescue_members():
    members_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUERS)
    available_members = (
        members_ref.where("status", "==", "Free")
                   .where("teamId", "==", None)
                   .stream()
    )
    return [m.to_dict() for m in available_members]
