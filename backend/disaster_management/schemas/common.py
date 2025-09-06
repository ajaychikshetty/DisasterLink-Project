from pydantic import BaseModel
from typing import Optional

class Location(BaseModel):
    latitude: float
    longitude: float
