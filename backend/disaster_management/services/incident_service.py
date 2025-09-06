# services/incident_service.py
from firebase import db
from schemas.incident import IncidentCreate, IncidentResponse, IncidentStatus
from datetime import datetime
from pytz import timezone

def create_new_incident(incident_data: IncidentCreate) -> IncidentResponse:
    """Creates a new incident in Firestore."""
    inc_ref = db.collection("incidents").document()
    
    # Create the full incident object, including server-generated fields
    ist = timezone('Asia/Kolkata')
    full_incident_data = IncidentResponse(
        incidentId=inc_ref.id,
        status=IncidentStatus.REPORTED,
        timestamp=datetime.utcnow().replace(tzinfo=timezone('UTC')).astimezone(ist),
        **incident_data.model_dump()
    )
    
    inc_ref.set(full_incident_data.model_dump())
    return full_incident_data