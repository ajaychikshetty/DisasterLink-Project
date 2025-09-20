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
from pytz import timezone as pytz_timezone



def update_victim_location(lat: float, lon: float, bat: int, phone: str):
    # get id==phone from victims collection    
    # update the victim document
    # trim leading + from phone if present
    if phone.startswith("+"):
        phone = phone[1:]
    doc_ref = db.collection(settings.FIREBASE_COLLECTION_VICTIMS).document(phone)
    ist = pytz_timezone('Asia/Kolkata')
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
    ist = pytz_timezone('Asia/Kolkata')
    now_ist = datetime.now(ist)
    victim_data = {
        "status": status,
        "updatedAt": int(now_ist.timestamp() * 1000)

    }
    doc_ref.update(victim_data)






















import random
import uuid
from datetime import timedelta


@router.get("/generate-dummy", status_code=201)
def generate_dummy_victims():
    """
    Creates 5 dummy victims with randomized data and adds them to Firestore.
    The document ID for each victim is their phone number without the leading '+'.
    """
    created_victims = []
    
    # --- Data Pools for Randomization ---
    dummy_names = [
        {"name": "Aarav Sharma", "gender": "Male"},
        {"name": "Saanvi Patel", "gender": "Female"},
        {"name": "Advik Singh", "gender": "Male"},
        {"name": "Ananya Reddy", "gender": "Female"},
        {"name": "Vivaan Kumar", "gender": "Male"}
    ]
    blood_groups = ["A+", "B+", "O-", "AB+", "A-", "O+"]
    statuses = ["Critical", "Needs Help", "Active", "Critical", "Needs Help"]
    base_lat, base_lon = 18.99, 73.12  # Centered around Kalyan
    
    for i in range(5):
        now = datetime.now(timezone.utc)
        
        # Generate a random date of birth for an adult (18 to 60 years old)
        dob = now - timedelta(days=random.randint(18*365, 60*365))
        
        # Generate a unique phone number to use as the document ID
        phone_number_int = 918877660 + i
        phone_number_str = f"+{phone_number_int}"
        doc_id = str(phone_number_int)

        victim_data = {
            "assignedTeamID": None,
            "authId": str(uuid.uuid4()),
            "battery": random.randint(15, 100),
            "bloodGroup": random.choice(blood_groups),
            "city": "Kalyan",
            "createdAt": now,
            "dateOfBirth": dob,
            "gender": dummy_names[i]["gender"],
            "isActive": True,
            "latitude": base_lat + random.uniform(-0.02, 0.02),
            "longitude": base_lon + random.uniform(-0.02, 0.02),
            "name": dummy_names[i]["name"],
            "phoneNumber": phone_number_str,
            "status": random.choice(statuses),
            "updatedAt": now
        }
        
        # Add the new victim to the 'victims' collection
        db.collection(settings.FIREBASE_COLLECTION_VICTIMS).document(doc_id).set(victim_data)
        created_victims.append(victim_data)
        
    return {
        "message": f"{len(created_victims)} dummy victims created successfully.",
        "victims_created": created_victims
    }
