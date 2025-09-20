# sms_handler.py
import json
from pydantic import ValidationError
from schemas.common import Location
from schemas.incident import IncidentCreate
from services import user_service, incident_service 
from routers.users import get_user_by_phone

from routers.victims import update_victim_location
from routers.rescuers import update_rescuer_location
from routers.shelters import add_member_to_shelter
from routers.rescue_ops import sendVictimListToTeamMember




# @router.post("/receive_sms")
def handle_sms_command(from_phone: str, body: str) -> str:
    """
    Parses and routes an incoming SMS command to the correct service.
    Returns the text for the reply SMS.
    """
    try:
        command, payload_str = body.split(" ", 1)
        payload = json.loads(payload_str)
        command = payload.get("msg", command)  
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
        

    elif command == "User Location update":
        # params: update_victim_location(lat: float, lon: float, msg: str, bat: int, time: str, phone: str):            
        update_victim_location(
            lat=payload.get("lat"),
            lon=payload.get("lon"),
            bat=payload.get("bat"),
            time=payload.get("time"),
            phone=from_phone
        )

    elif command == "Rescuer Location update":
        # params: update_rescuer_location(lat: float, lon: float, msg: str, bat: int, time: str, id: str):
        update_rescuer_location(
            lat=payload.get("lat"),
            lon=payload.get("lon"),
            time=payload.get("time"),
            id=payload.get("rescuer_email")
        )

    elif command == "201": # add member to shelter
        # params: addUserToShelter(shelterId: str, phone: str):
        add_member_to_shelter(
            shelterId=payload.get("shelterId"),
            memberId=from_phone
        )

    elif command == "1":
        # params: sendVictimListToTeamMember(rescuerId: str):
        sendVictimListToTeamMember(
            rescuerId=from_phone
        )


    


    # SEND NEAREST SHELTER ID, with list of users in that particular area when team is assigned



    else:
        return f"Unknown command: {command}."