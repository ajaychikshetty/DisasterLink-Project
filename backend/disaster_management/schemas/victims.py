# models/victims.py
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from schemas.common import Location


class Victim(BaseModel):
    authId: str
    bloodGroup: Optional[str] = None
    city: Optional[str] = None
    createdAt: datetime
    dateOfBirth: datetime
    gender: Optional[str] = None
    isActive: bool = True
    latitude: float
    longitude: float
    name: str
    phoneNumber: Optional[str] = None
    updatedAt: datetime
