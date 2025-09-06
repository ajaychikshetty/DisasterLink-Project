from pydantic import BaseModel, Field
from typing import Optional

class Location(BaseModel):
    latitude: float
    longitude: float

class UserCreate(BaseModel):
    name: str
    dob: str
    gender: str
    contactNo: str
    city: str
    bloodGroup: str
    location: Location

class UserResponse(UserCreate):
    userId: str
    age: int
    status: str = "Active"
