# shelter route

from os import name
from fastapi import APIRouter, HTTPException
from firebase import db
from config import settings
from schemas.shelter import ShelterCreate, ShelterResponse
from schemas.user import UserResponse
import time

router = APIRouter(prefix="/api/shelters", tags=["Shelters"])


def enrich_shelter_with_users(shelter: dict) -> dict:
    """Attach full user details for rescuedMembers."""
    users = []
    for uid in shelter.get("rescuedMembers", []):
        doc = db.collection(settings.FIREBASE_COLLECTION_USERS).document(uid).get()
        if doc.exists:
            users.append(UserResponse(**doc.to_dict()))
    shelter["rescuedMembers"] = users
    shelter["currentOccupancy"] = len(users)
    return shelter


# ---------- CREATE SHELTER ----------
@router.post("", response_model=ShelterResponse)
def create_shelter(shelter: ShelterCreate):
    ref = db.collection(settings.FIREBASE_COLLECTION_SHELTERS).document()
    data = shelter.dict()
    data.update({
        "id": ref.id,
        "rescuedMembers": [],
        "currentOccupancy": 0,
        "lastUpdated": int(time.time() * 1000),
    })
    ref.set(data)
    return enrich_shelter_with_users(data)


# ---------- LIST ALL SHELTERS ----------
@router.get("", response_model=list[ShelterResponse])
def list_shelters():
    shelters = db.collection(settings.FIREBASE_COLLECTION_SHELTERS).stream()
    results = []
    for s in shelters:
        data = s.to_dict()
        data["id"] = s.id
        results.append(enrich_shelter_with_users(data))
    return results


# ---------- GET SHELTER BY ID ----------
@router.get("/{shelterId}", response_model=ShelterResponse)
def get_shelter(shelterId: str):
    doc = db.collection(settings.FIREBASE_COLLECTION_SHELTERS).document(shelterId).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Shelter not found")
    data = doc.to_dict()
    data["id"] = doc.id
    return enrich_shelter_with_users(data)


# ---------- UPDATE SHELTER ----------
@router.put("/{shelterId}", response_model=ShelterResponse)
def update_shelter(shelterId: str, payload: dict):
    ref = db.collection(settings.FIREBASE_COLLECTION_SHELTERS).document(shelterId)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Shelter not found")

    payload["lastUpdated"] = int(time.time() * 1000)
    ref.update(payload)

    doc = ref.get()
    data = doc.to_dict()
    data["id"] = doc.id
    return enrich_shelter_with_users(data)


# ---------- DELETE SHELTER ----------
@router.delete("/{shelterId}")
def delete_shelter(shelterId: str):
    ref = db.collection(settings.FIREBASE_COLLECTION_SHELTERS).document(shelterId)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Shelter not found")
    ref.delete()
    return {"message": "Shelter deleted successfully"}


# ---------- ADD MEMBER ----------
@router.post("/{shelterId}/add-member/{memberId}", response_model=ShelterResponse)
def add_member_to_shelter(shelterId: str, memberId: str):
    ref = db.collection(settings.FIREBASE_COLLECTION_SHELTERS).document(shelterId)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Shelter not found")

    shelter = doc.to_dict()
    members = shelter.get("rescuedMembers", [])

    if memberId in members:
        raise HTTPException(status_code=400, detail="Member already in shelter")
    if len(members) >= shelter["capacity"]:
        raise HTTPException(status_code=400, detail="Shelter is at full capacity")

    members.append(memberId)
    shelter["rescuedMembers"] = members
    shelter["lastUpdated"] = int(time.time() * 1000)
    ref.update(shelter)

    shelter["id"] = doc.id
    return enrich_shelter_with_users(shelter)


# ---------- REMOVE MEMBER ----------
@router.post("/{shelterId}/remove-member/{memberId}", response_model=ShelterResponse)
def remove_member_from_shelter(shelterId: str, memberId: str):
    ref = db.collection(settings.FIREBASE_COLLECTION_SHELTERS).document(shelterId)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Shelter not found")

    shelter = doc.to_dict()
    members = shelter.get("rescuedMembers", [])
    if memberId not in members:
        raise HTTPException(status_code=400, detail="Member not in shelter")

    members.remove(memberId)
    shelter["rescuedMembers"] = members
    shelter["lastUpdated"] = int(time.time() * 1000)
    ref.update(shelter)

    shelter["id"] = doc.id
    return enrich_shelter_with_users(shelter)






# shelter sms:

def addUserToShelter(shelterId: str, phone: str):
    # rescuedmember[userid] = phone
    ref = db.collection(settings.FIREBASE_COLLECTION_SHELTERS).document(shelterId)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Shelter not found")

    shelter = doc.to_dict()
    members = shelter.get("rescuedMembers", {})

    # get name from victims collection:
    doc_ref = db.collection(settings.FIREBASE_COLLECTION_VICTIMS).document(phone)
    victim = doc_ref.get()
    if not victim.exists:    
        raise HTTPException(status_code=404, detail="Victim not found")
    
    name = victim.to_dict().get("name", "Unknown")
    
    members[phone] = name
    shelter["rescuedMembers"] = members
    shelter["lastUpdated"] = int(time.time() * 1000)
    ref.update(shelter)

    # update the victim isActive to false:
    doc_ref = db.collection(settings.FIREBASE_COLLECTION_VICTIMS).document(phone)
    victim_data = {
        "isActive": False,
        "updatedAt": int(time.time() * 1000)
    }
    doc_ref.update(victim_data)


