# services/user_service.py
from firebase import db
from config import settings
from schemas.user import UserCreate, UserResponse, Location
from schemas.communication import StatusUpdate
from fastapi import HTTPException
from utils.common import calculate_age
from routers.users import get_user_by_phone, update_user



def update_user_status_and_location(user_id: str, status: str, location: Location) -> dict:
    """Updates a user's status and location in Firestore using the router API."""
    payload = {
        "status": status,
        "location": location.model_dump()
    }

    updated_user = update_user(user_id, payload)
    return {"userId": user_id, "status": status, "message": "Status and location updated successfully", "user": updated_user}
