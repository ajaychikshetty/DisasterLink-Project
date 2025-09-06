# backend/app/routes/rescue_ops.py
from utils.sms import send_sms
from fastapi import APIRouter, HTTPException
from firebase import db
from config import settings
from schemas.rescue import RescueTeamCreate, RescueTeamResponse, RescueTeamUpdate
from utils.geo import haversine as haversine_distance
from uuid import uuid4

router = APIRouter(prefix="/api", tags=["Rescue Ops"])

# Create team
@router.post("/rescue-ops/teams", response_model=RescueTeamResponse)
def create_team(team: RescueTeamCreate):
    team_id = str(uuid4())
    # Ensure leader included in members list if provided
    members = team.members or []
    if team.leader and team.leader not in members:
        members.append(team.leader)

    data = {
        "teamId": team_id,
        "teamName": team.name,
        "leader": team.leader,
        "members": members,
        "status": "Free",
        "assignedIncident": None,
        "location": team.location.dict() if team.location else None
    }
    ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(team_id)
    ref.set(data)

    # Also update the rescuer's teamId if leader exists
    if team.leader:
        try:
            db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(team.leader).update({"teamId": team_id, "teamName": team.name})
        except Exception:
            # If rescuer document doesn't exist, ignore for now
            pass

    return data

# Get team
@router.get("/rescue-ops/teams/{teamId}", response_model=RescueTeamResponse)
def get_team(teamId: str):
    doc = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(teamId).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Team not found")
    return doc.to_dict()

# List teams
@router.get("/rescue-ops/teams", response_model=list[RescueTeamResponse])
def list_teams():
    teams = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).stream()
    return [t.to_dict() for t in teams]

# Update team
@router.put("/rescue-ops/teams/{teamId}", response_model=RescueTeamResponse)
def update_team(teamId: str, team_update: RescueTeamUpdate):
    team_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(teamId)
    team_doc = team_ref.get()
    if not team_doc.exists:
        raise HTTPException(status_code=404, detail="Team not found")

    team_data = team_doc.to_dict()
    existing_members = set(team_data.get("members", []))
    new_members = set(team_update.members)

    # Ensure leader is part of members
    if team_update.leader not in new_members:
        new_members.add(team_update.leader)

    members_to_add = new_members - existing_members
    members_to_remove = existing_members - new_members

    update_data = {
        "name": team_update.name,
        "leader": team_update.leader,
        "members": list(new_members),
        "location": team_update.location.dict() if team_update.location else team_data.get("location")
    }
    team_ref.update(update_data)

    for username in members_to_add:
        try:
            db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(username).update({"teamId": teamId, "teamName": team_update.name})
        except Exception:
            pass

    for username in members_to_remove:
        try:
            db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(username).update({"teamId": None, "teamName": None})
        except Exception:
            pass

    return team_ref.get().to_dict()

# Delete team
@router.delete("/rescue-ops/teams/{teamId}")
def delete_team(teamId: str):
    ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(teamId)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Team not found")
    # optionally clear teamId from members
    team = ref.get().to_dict()
    for member in team.get("members", []):
        try:
            db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(member).update({"teamId": None, "teamName": None})
        except Exception:
            pass
    ref.delete()
    return {"message": "Rescue team deleted successfully"}

# Add members endpoint
@router.post("/rescue-ops/teams/{teamId}/members", response_model=RescueTeamResponse)
def add_members(teamId: str, payload: dict):
    ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(teamId)
    team = ref.get()
    if not team.exists:
        raise HTTPException(status_code=404, detail="Team not found")

    members = payload.get("members", [])
    team_data = team.to_dict()
    updated_members = list(dict.fromkeys(team_data.get("members", []) + members))  # avoid duplicates

    ref.update({"members": updated_members})
    for m in members:
        try:
            db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(m).update({"teamId": teamId, "teamName": team_data.get("name")})
        except Exception:
            pass
    return ref.get().to_dict()

# Rescue logging
@router.post("/rescue-log")
def log_rescue(payload: dict):
    try:
        shelter_ref = db.collection(settings.FIREBASE_COLLECTION_SHELTERS).document(payload["shelterId"])
        shelter = shelter_ref.get()
        if not shelter.exists:
            raise HTTPException(status_code=404, detail="Shelter not found")

        shelter_data = shelter.to_dict()
        rescued = payload["rescuedCount"]

        updated = {
            "rescuedCount": shelter_data.get("rescuedCount", 0) + rescued.get("total", 0),
            "kidsCount": shelter_data.get("kidsCount", 0) + rescued.get("kids", 0),
            "womenCount": shelter_data.get("womenCount", 0) + rescued.get("women", 0),
            "menCount": shelter_data.get("menCount", 0) + rescued.get("men", 0),
        }
        shelter_ref.update(updated)

        return {"message": "Rescue logged successfully", "updatedShelter": shelter_ref.get().to_dict()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# Auto assign by location
@router.post("/auto-assign-location")
def auto_assign_location(payload: dict):
    try:
        latitude = float(payload["latitude"])
        longitude = float(payload["longitude"])
        incident_id = payload.get("incidentId")

        teams_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).where("status", "==", "Free").stream()
        nearest_team = None
        min_dist = float("inf")

        for t in teams_ref:
            t_data = t.to_dict()
            # Prefer team location, fallback to leader location
            team_loc = t_data.get("location")
            if team_loc and team_loc.get("latitude") is not None:
                lat2 = team_loc.get("latitude")
                lon2 = team_loc.get("longitude")
            else:
                leader_id = t_data.get("leader")
                leader_doc = None
                if leader_id:
                    leader_doc = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(leader_id).get()
                if leader_doc and leader_doc.exists:
                    leader_data = leader_doc.to_dict()
                    loc = leader_data.get("location") or {}
                    lat2 = loc.get("latitude")
                    lon2 = loc.get("longitude")
                else:
                    lat2 = None
                    lon2 = None

            dist = haversine_distance(latitude, longitude, lat2, lon2)
            if dist < min_dist:
                nearest_team = t
                min_dist = dist

        if not nearest_team:
            raise HTTPException(status_code=404, detail="No free rescue teams available")

        nearest_team.reference.update({"status": "Engaged", "assignedIncident": incident_id})


        if nearest_team:
            nearest_team.reference.update({"status": "Engaged", "assignedIncident": incident_id})

            # ---- NEW NOTIFICATION LOGIC ----
            # Find users within a certain radius (e.g., 2km) of the incident
            incident_location = {"latitude": latitude, "longitude": longitude}
            notification_radius_km = 2
            users_to_notify = []
            
            users_stream = db.collection(settings.FIREBASE_COLLECTION_USERS).stream()
            for u in users_stream:
                user_data = u.to_dict()
                user_loc = user_data.get("location")
                if user_loc:
                    dist = haversine_distance(
                        incident_location["latitude"], incident_location["longitude"],
                        user_loc["latitude"], user_loc["longitude"]
                    )
                    if dist <= notification_radius_km:
                        users_to_notify.append(user_data["contactNo"])
            
            if users_to_notify:
                message = f"ALERT: A rescue team has been dispatched to your area for incident {incident_id}. Please follow instructions from authorities."
                send_sms(users_to_notify, message)
            # ---- END NOTIFICATION LOGIC ----

            return {
                "message": "Rescue team auto-assigned and nearby users notified.",
                "assignedTeam": nearest_team.id,
                "distance_km": round(min_dist, 2)
            }


        return {
            "message": "Rescue team auto-assigned successfully",
            "assignedTeam": nearest_team.id,
            "distance_km": round(min_dist, 2)
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# Manual assign
@router.post("/rescue-ops/teams/{teamId}/assign")
def manual_assign_team(teamId: str, payload: dict):
    incident_id = payload.get("incidentId")
    if not incident_id:
        raise HTTPException(status_code=400, detail="Incident ID is required")

    ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(teamId)
    team = ref.get()
    if not team.exists:
        raise HTTPException(status_code=404, detail="Team not found")

    team_data = team.to_dict()
    if team_data.get("status") != "Free":
        raise HTTPException(status_code=400, detail="Team is not free for assignment")

    ref.update({"status": "Engaged", "assignedIncident": incident_id})
    return {"message": f"Team {teamId} manually assigned to incident {incident_id}"}
