# disaster_management/routers/rescuers.py

from fastapi import APIRouter, HTTPException
from firebase import db
from config import settings
from schemas.rescue import (
    RescueMemberCreate,
    RescueMemberResponse,
)
from firebase_admin import auth

router = APIRouter(prefix="/api", tags=["Rescuers"])

# ================== Rescue Members ==================

# Create a rescue member (auto Firestore ID)
@router.post("/rescuemembers", response_model=RescueMemberResponse)
def create_rescue_member(member: RescueMemberCreate):
    """
    Creates a user in Firebase Auth and a corresponding document in Firestore.
    The document ID in Firestore is the user's email.
    """
    # Step 1: Create the user in Firebase Authentication
    try:
        user_record = auth.create_user(
            email=member.email,
            password="Password@123"  # Hardcoded password as requested
        )
    except auth.EmailAlreadyExistsError:
        # If the email is already in use, return a conflict error
        raise HTTPException(
            status_code=409,
            detail=f"An authentication account with email '{member.email}' already exists."
        )
    except Exception as e:
        # Handle other potential errors from Firebase
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create authentication user: {str(e)}"
        )

    # Step 2: Use the email as the document ID for the Firestore record
    ref = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(member.email)
    
    # Check if a document with this ID already exists in Firestore (optional but recommended)
    if ref.get().exists:
        # If you reach here, it means the auth user was just created but the firestore doc
        # somehow exists. This indicates an inconsistent state.
        # You might want to delete the newly created auth user before raising the error.
        auth.delete_user(user_record.uid)
        raise HTTPException(
            status_code=409,
            detail=f"A rescuer profile with ID '{member.email}' already exists in the database."
        )

    # Step 3: Prepare and save the data to Firestore
    data = member.dict()
    data.update({
        "id": member.email,      # Use email as the ID field within the document
        "auth_uid": user_record.uid, # Store the auth UID to link the records
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
    members_stream = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).stream()
    
    response_list = []
    for member_doc in members_stream:
        # Convert the Firestore document to a dictionary
        member_data = member_doc.to_dict()
        
        # Get latitude and longitude from the dictionary
        latitude = member_data.get("latitude")
        longitude = member_data.get("longitude")
        
        # If both latitude and longitude exist, create a nested 'location' object
        if latitude is not None and longitude is not None:
            member_data["location"] = {"latitude": latitude, "longitude": longitude}
        else:
            member_data["location"] = None
            
        response_list.append(member_data)
        
    return response_list

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

















# rescuer sms:
from datetime import datetime
from pytz import timezone

def update_rescuer_location(lat: float, lon: float, id: str):
    # get id==phone from victims collection    
    # remove leading + from id if present
    # update the victim document
    print("inside update_rescuer_location")
    print("id:", id)
    print("lat:", lat)
    print("lon:", lon)

    doc_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(id)
    ist = timezone('Asia/Kolkata')
    now_ist = datetime.now(ist)
    victim_data = {
        "latitude": lat,
        "longitude": lon,
        "updatedAt": int(now_ist.timestamp() * 1000)
    }
    doc_ref.update(victim_data)


