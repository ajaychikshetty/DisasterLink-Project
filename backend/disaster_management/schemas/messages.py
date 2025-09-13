# schemas/messages.py

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from .common import Location


class MessageBase(BaseModel):
    sender: str = Field(..., alias="Sender")
    type: int = Field(..., alias="Type")
    battery: Optional[int] = Field(None, alias="Battery")
    timestamp: datetime = Field(..., alias="Timestamp")
    message: str = Field(..., alias="Message")
    location: Optional[Location] = None

    class Config:
        allow_population_by_field_name = True
