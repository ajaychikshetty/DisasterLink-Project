# schemas/incident.py

from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum
from datetime import datetime
from .common import Location

class IncidentType(str, Enum):
    FLOOD = "Flood"
    FIRE = "Fire"
    BUILDING_COLLAPSE = "Building Collapse"
    LANDSLIDE = "Landslide"
    MEDICAL_EMERGENCY = "Medical Emergency"
    OTHER = "Other"

class IncidentSeverity(str, Enum):
    LOW = "Low"
    MEDIUM = "Medium"
    HIGH = "High"
    CRITICAL = "Critical"

class IncidentStatus(str, Enum):
    REPORTED = "Reported"
    VERIFIED = "Verified"
    IN_PROGRESS = "In Progress"
    RESOLVED = "Resolved"

class IncidentCreate(BaseModel):
    type: IncidentType
    location: Location
    severity: IncidentSeverity
    reportedBy: str  # User ID
    description: Optional[str] = None

class IncidentUpdate(BaseModel):
    status: Optional[IncidentStatus] = None
    severity: Optional[IncidentSeverity] = None
    description: Optional[str] = None

class IncidentResponse(IncidentCreate):
    incidentId: str
    status: IncidentStatus = IncidentStatus.REPORTED
    timestamp: datetime