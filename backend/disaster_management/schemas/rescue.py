# rescue schema, rescuers + rescue ops

from pydantic import BaseModel, Field
from typing import List, Optional
from schemas.common import Location

# Rescue Member
class RescueMemberCreate(BaseModel):
    name: str
    dob: str
    phone: str
    status: Optional[str] = "Free"
    loginAvailable: Optional[bool] = True

class RescueMemberResponse(BaseModel):
    id: str  # <-- Firestore auto ID
    name: str
    dob: str
    phone: str
    status: str = "Free"
    loginAvailable: Optional[bool] = True
    teamId: Optional[str] = None
    teamName: Optional[str] = None
    location: Optional[Location] = None


# Rescue Team
class RescueTeamResponse(BaseModel):
    teamId: str
    teamName: Optional[str] = None
    leader: Optional[str] = None
    members: List[str] = Field(default_factory=list)
    status: str = "Free"
    assignedIncident: Optional[str] = None
    location: Optional[Location] = None

class RescueTeamUpdate(BaseModel):
    name: str
    leader: str
    members: List[str] = Field(default_factory=list)
    location: Optional[Location] = None


class RescueTeamCreate(BaseModel):
    name: str
    leader: Optional[str] = None  # id/username of leader
    # optional fields client may pass
    members: Optional[List[str]] = Field(default_factory=list)
    location: Optional[Location] = None
