from fastapi import APIRouter, HTTPException
from firebase import db
from config import settings
from schemas.communication import StatusUpdate, Broadcast
# from utils.sms import send_sms
from utils.geo import haversine

router = APIRouter(prefix="/api", tags=["Communication"])

# User status update
@router.post("/users/{userId}/status")
def update_status(userId: str, status: StatusUpdate):
    ref = db.collection(settings.FIREBASE_COLLECTION_USERS).document(userId)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
    ref.update({"status": status.status})
    return {"userId": userId, "status": status.status, "message": "Status updated successfully"}





# Broadcast
@router.post("/broadcast")
def broadcast(b: Broadcast):
    users = db.collection(settings.FIREBASE_COLLECTION_USERS).stream()
    recipients = []
    if b.area:
        for u in users:
            data = u.to_dict()
            print(data)
            dist = haversine(
                b.area["latitude"], b.area["longitude"],
                data["location"]["latitude"], data["location"]["longitude"]
            )
            if dist <= b.area["radius"]:
                recipients.append(data["contactNo"])
    else:
        recipients = [u.to_dict()["contactNo"] for u in users]
    
    if not recipients:
        return {"message": "No users found in target area", "recipients": 0}
    
    send_sms(recipients, b.message)
    return {"message": "Broadcast sent successfully.", "recipients": len(recipients)}
