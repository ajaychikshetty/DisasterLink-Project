from pydantic import BaseModel
from typing import Optional
from schemas.common import Location

class StatusUpdate(BaseModel):
    status: str  # "Safe" or "Needs Immediate Help"

class Broadcast(BaseModel):
    message: str
    area: Optional[dict] = None  # { latitude, longitude, radius }
