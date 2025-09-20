# routes/victims.py
from fastapi import APIRouter, HTTPException
from typing import List
from schemas.victims import Victim
from datetime import datetime, timezone
from config import settings
from firebase import db

router = APIRouter(prefix="/api/victims", tags=["Victims"])

# In-memory store for now (replace with DB later)
victims_db: List[Victim] = []

@router.get("", response_model=List[Victim])
def get_victims():
    docs = db.collection(settings.FIREBASE_COLLECTION_VICTIMS).stream()
    victims = []
    for doc in docs:
        victim = doc.to_dict()
        if victim.get("isActive") is True:
        #     if "authId" in victim:
        #         victim["victimId"] = victim.pop("authId")
            victims.append(victim)

    print(victims)
    print("******************************************************************8")
    print("******************************************************************8")
    print("******************************************************************8")
    print("******************************************************************8")
    print("******************************************************************8")

    return victims












# victim sms:
from pytz import timezone


def update_victim_location(lat: float, lon: float, bat: int, phone: str):
    # get id==phone from victims collection    
    # update the victim document
    # trim leading + from phone if present
    if phone.startswith("+"):
        phone = phone[1:]
    doc_ref = db.collection(settings.FIREBASE_COLLECTION_VICTIMS).document(phone)
    ist = timezone('Asia/Kolkata')
    now_ist = datetime.now(ist)
    victim_data = {
        "latitude": lat,
        "longitude": lon,
        "battery": bat,
        "updatedAt": int(now_ist.timestamp() * 1000)

    }
    doc_ref.update(victim_data)


def updateStatus(phone: str, status: str):
    # get id==phone from victims collection    
    # update the victim document
    # trim leading + from phone if present
    if phone.startswith("+"):
        phone = phone[1:]
    doc_ref = db.collection(settings.FIREBASE_COLLECTION_VICTIMS).document(phone)
    ist = timezone('Asia/Kolkata')
    now_ist = datetime.now(ist)
    victim_data = {
        "status": status,
        "updatedAt": int(now_ist.timestamp() * 1000)

    }
    doc_ref.update(victim_data)