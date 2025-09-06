# sms_handler.py
import json
from pydantic import ValidationError
from schemas.common import Location
from schemas.incident import IncidentCreate
from services import user_service, incident_service 
from routers.users import get_user_by_phone

def handle_sms_command(from_phone: str, body: str) -> str:
    """
    Parses and routes an incoming SMS command to the correct service.
    Returns the text for the reply SMS.
    """
    try:
        command, payload_str = body.split(" ", 1)
        payload = json.loads(payload_str)
    except (ValueError, json.JSONDecodeError):
        return "Invalid command format. Use: COMMAND {\"json\": \"payload\"}"

    # First, identify the user sending the SMS
    user = get_user_by_phone(from_phone)
    if not user:
        return "Your phone number is not registered with the system. Cannot process request."

    # Route command to the appropriate logic
    if command == "USER_STATUS_UPDATE":
        try:
            status = payload["status"]
            location = Location.model_validate(payload["location"])
            user_service.update_user_status_and_location(user['userId'], status, location)
            return f"Success! Your status has been updated to '{status}'."
        except (ValidationError, KeyError) as e:
            return f"Error: Invalid data for STATUS_UPDATE. Details: {e}"

    elif command == "INCIDENT_REPORT":
        try:
            # Add the user's ID to the incident report
            payload["reportedBy"] = user['userId']
            incident_data = IncidentCreate.model_validate(payload)
            new_incident = incident_service.create_new_incident(incident_data)
            return f"Incident reported successfully. Your incident ID is {new_incident.incidentId}."
        except (ValidationError, KeyError) as e:
            return f"Error: Invalid data for INCIDENT_REPORT. Details: {e}"

    # Add more command handlers here (e.g., GET_SHELTERS)
    # elif command == "GET_SHELTERS":
    #     ... call a shelter_service to find nearest shelters ...
    #     return "Shelter info..."

    else:
        return f"Unknown command: {command}. Supported commands: STATUS_UPDATE, INCIDENT_REPORT."