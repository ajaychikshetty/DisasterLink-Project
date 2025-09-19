# shelter schema

from pydantic import BaseModel
from typing import List, Optional
import time
from schemas.user import UserResponse


class ShelterCreate(BaseModel):
    name: str
    address: str
    description: Optional[str] = None
    capacity: int
    contactNumber: str
    latitude: float
    longitude: float
    amenities: List[str] = []
    status: str = "Available"
    isActive: bool = True


class ShelterResponse(ShelterCreate):
    id: str
    currentOccupancy: int = 0
    rescuedMembers: List[UserResponse] = []   # ✅ full user details, not just IDs
    lastUpdated: int = int(time.time() * 1000)
