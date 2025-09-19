from fastapi import APIRouter, HTTPException, status
from firebase import db
from schemas.messages import MessageBase, Location
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

        # Convert GeoPoint to Location dict
        geo_point = message_data.get("location")
        if geo_point:
            message_data["location"] = {
                "latitude": geo_point.latitude,
                "longitude": geo_point.longitude
            }

        messages_list.append(MessageBase.model_validate(message_data))

    return messages_list


@router.get("/{message_id}", response_model=MessageBase)
async def get_message(message_id: str):
    if not db:
        raise HTTPException(500, "Database not connected.")

    message_ref = db.collection(settings.FIREBASE_COLLECTION_MESSAGES).document(message_id)
    message_doc = message_ref.get()

    if not message_doc.exists:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Message not found.")

    message_data = message_doc.to_dict()

    # Convert GeoPoint to Location dict
    geo_point = message_data.get("location")
    if geo_point:
        message_data["location"] = {
            "lat": geo_point.latitude,
            "lng": geo_point.longitude
        }

    return MessageBase.model_validate(message_data)
