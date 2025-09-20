# backend/app/schemas/rescue.py

from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from enum import Enum
from .common import Location # Assuming you have a common schema for Location

# --- Enums for status choices ---
class TeamStatus(str, Enum):
    FREE = "Free"
    ASSIGNED = "Assigned"
    UNAVAILABLE = "Unavailable"
    UNKNOWN = "Unknown"


# --- Rescuer Schemas ---
class RescueMemberCreate(BaseModel):
    email: str
    name: str
    dob: str
    phone: str
    status: Optional[str] = "Free"
    loginAvailable: Optional[bool] = True

class RescueMemberResponse(BaseModel):
    id: str
    name: str
    dob: str
    phone: str
    status: str = "Free"
    loginAvailable: Optional[bool] = True
    teamId: Optional[str] = None
    teamName: Optional[str] = None
    location: Optional[Location] = None


# --- Team Schemas (NEW STRUCTURE) ---

class LeaderInfo(BaseModel):
    id: str
    name: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class RescueTeamCreate(BaseModel):
    teamName: str
    leader: Optional[str] = None  # Leader's ID
    members: List[str] = Field(default_factory=list) # List of member IDs

class RescueTeamUpdate(BaseModel):
    teamName: Optional[str] = None
    leader: Optional[str] = None
    members: Optional[List[str]] = None

class RescueTeamResponse(BaseModel):
    teamAddress: Optional[str] = None
    teamId: str
    teamName: Optional[str] = None
    leader: Optional[LeaderInfo] = None
    members: Dict[str, Optional[str]] = Field(default_factory=dict) # {id: name, id: name}
    status: TeamStatus = TeamStatus.UNKNOWN
    assignedLatitude: Optional[float] = None
    assignedLongitude: Optional[float] = None
    nearestVictims: Optional[List[str]] = None