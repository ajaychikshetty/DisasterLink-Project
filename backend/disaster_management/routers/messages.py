from fastapi import APIRouter, HTTPException, status
from firebase import db
from schemas.messages import MessageBase
from typing import List
from config import settings

router = APIRouter(prefix="/api/messages", tags=["Messages"])

@router.get("/", response_model=List[MessageBase])
async def get_all_messages():
    if not db:
        raise HTTPException(500, "Database not connected.")

    messages_ref = db.collection(settings.FIREBASE_COLLECTION_MESSAGES)
    messages = messages_ref.stream()

    messages_list = []

    for message in messages:
        message_data = message.to_dict()

        print("🔥 Raw message from Firebase:", message_data)  # 👈 log raw data

        # Convert GeoPoint to Location dict
        geo_point = message_data.get("location")
        if geo_point:
            message_data["location"] = {
                "latitude": geo_point.latitude,
                "longitude": geo_point.longitude
            }

        msg = MessageBase.model_validate(message_data)
        messages_list.append(msg)

    print("✅ Final messages list:", messages_list)  # 👈 log final output
    return messages_list
