# backend/app/routes/rescue_ops.py

from fastapi import APIRouter, HTTPException, Body
from firebase_admin import firestore
from firebase import db
from config import settings
from schemas import victims
from schemas.rescue import (
    RescueTeamCreate, 
    RescueTeamResponse, 
    RescueTeamUpdate, 
    LeaderInfo,
    TeamStatus
)
from uuid import uuid4
from typing import List
from math import radians, cos, sin, asin, sqrt
from routers.sms import send_sms


router = APIRouter(prefix="/api", tags=["Rescue Ops"])

def _fetch_rescuers_data(rescuer_ids: list) -> dict:
    """Helper function to fetch rescuer data in batches."""
    if not rescuer_ids:
        return {}
    
    rescuers_map = {}
    # Firestore 'in' query supports up to 30 elements
    for i in range(0, len(rescuer_ids), 30):
        batch_ids = rescuer_ids[i:i+30]
        rescuers_query = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).where("id", "in", batch_ids).stream()
        for rescuer in rescuers_query:
            rescuer_data = rescuer.to_dict()
            rescuers_map[rescuer_data["id"]] = rescuer_data
    return rescuers_map

def _construct_team_response(team_doc: firestore.DocumentSnapshot) -> dict:
    """Helper function to construct the detailed team response, including nearby victims."""
    team_data = team_doc.to_dict()
    if not team_data:
        return None

    leader_id = team_data.get("leader")
    member_ids = team_data.get("members", [])
    all_rescuer_ids = list(set([leader_id] + member_ids) - {None})

    rescuers_data = _fetch_rescuers_data(all_rescuer_ids)

    # Construct leader info
    leader_info = None
    if leader_id and leader_id in rescuers_data:
        leader_data = rescuers_data[leader_id]
        leader_info = LeaderInfo(
            id=leader_id,
            name=leader_data.get("name"),
            latitude=leader_data.get("latitude"),
            longitude=leader_data.get("longitude")
        )

    # Construct members dictionary
    members_dict = {
        member_id: rescuers_data.get(member_id, {}).get("name")
        for member_id in member_ids
    }

    # Find victims within 5km of assigned location
    assigned_lat = team_data.get("assignedLatitude")
    assigned_lon = team_data.get("assignedLongitude")
    nearby_victims = []
    if assigned_lat is not None and assigned_lon is not None:
        victims_ref = db.collection(settings.FIREBASE_COLLECTION_VICTIMS).where("isActive", "==", True)
        victims_docs = victims_ref.stream()
        victims = []
        for victim in victims_docs:
            victim_data = victim.to_dict()
            if victim_data.get("isActive") is True:
                victims.append(victim_data)
        nearby_victims = find_nearest_victims(assigned_lat, assigned_lon, victims)

    return RescueTeamResponse(
        teamId=team_data["teamId"],
        teamName=team_data.get("teamName"),
        leader=leader_info,
        members=members_dict,
        status=team_data.get("status", TeamStatus.UNKNOWN),
        assignedLatitude=team_data.get("assignedLatitude"),
        assignedLongitude=team_data.get("assignedLongitude"),
        teamAddress=get_address_from_latlong(team_data.get("assignedLatitude"), team_data.get("assignedLongitude")),
        victimsNearby=nearby_victims
    ).dict()

@router.post("/rescue-ops/teams", response_model=RescueTeamResponse, status_code=201)
def create_team(team: RescueTeamCreate):
    """Creates a new rescue team."""
    team_id = str(uuid4())
    members = set(team.members)
    if team.leader:
        members.add(team.leader)

    team_data = {
        "teamId": team_id,
        "teamName": team.teamName,
        "leader": team.leader,
        "members": list(members),
        "status": TeamStatus.FREE.value,
        "assignedLatitude": None,
        "assignedLongitude": None
    }
    
    team_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(team_id)
    team_ref.set(team_data)

    # Update teamId for all members
    for member_id in members:
        try:
            db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(member_id).update({
                "teamId": team_id,
                "teamName": team.teamName,
                "status": TeamStatus.ASSIGNED.value
            })
        except Exception:
            pass # Ignore if a rescuer doesn't exist

    return _construct_team_response(team_ref.get())

@router.get("/rescue-ops/teams", response_model=List[RescueTeamResponse])
def list_teams():
    """Lists all rescue teams with enriched leader and member data."""
    teams_stream = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).stream()
    return [_construct_team_response(team_doc) for team_doc in teams_stream]

@router.get("/rescue-ops/teams/{team_id}", response_model=RescueTeamResponse)
def get_team(team_id: str):
    """Retrieves a single team by its ID with enriched data."""
    team_doc = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(team_id).get()
    if not team_doc.exists:
        raise HTTPException(status_code=404, detail="Team not found")
    return _construct_team_response(team_doc)

@router.put("/rescue-ops/teams/{team_id}", response_model=RescueTeamResponse)
def update_team(team_id: str, team_update: RescueTeamUpdate):
    """Updates a team's information."""
    team_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(team_id)
    if not team_ref.get().exists:
        raise HTTPException(status_code=404, detail="Team not found")

    update_data = team_update.dict(exclude_unset=True)
    
    # Ensure leader is always in members list if members are being updated
    if 'members' in update_data and 'leader' in update_data:
        if update_data['leader'] not in update_data['members']:
            update_data['members'].append(update_data['leader'])
    # update the status and teamId and teamName of all members
    if 'members' in update_data or 'leader' in update_data or 'teamName' in update_data:
        team_doc = team_ref.get().to_dict()
        new_members = set(update_data.get('members', team_doc.get('members', [])))
        new_leader = update_data.get('leader', team_doc.get('leader'))
        if new_leader:
            new_members.add(new_leader)
        new_team_name = update_data.get('teamName', team_doc.get('teamName'))

        # Fetch current members to identify removals
        current_members = set(team_doc.get('members', []))
        if team_doc.get('leader'):
            current_members.add(team_doc.get('leader'))

        # Members to be removed
        members_to_remove = current_members - new_members
        for member_id in members_to_remove:
            try:
                db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(member_id).update({
                    "teamId": None,
                    "teamName": None,
                    "status": TeamStatus.FREE.value
                })
            except Exception:
                pass # Ignore if a rescuer doesn't exist

        # Update new members with the latest team info
        for member_id in new_members:
            try:
                db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(member_id).update({
                    "teamId": team_id,
                    "teamName": new_team_name,
                    "status": TeamStatus.ASSIGNED.value
                })
            except Exception:
                pass # Ignore if a rescuer doesn't exist

    team_ref.update(update_data)
    return _construct_team_response(team_ref.get())


@router.delete("/rescue-ops/teams/{team_id}", status_code=204)
def delete_team(team_id: str):
    """Deletes a rescue team and unlinks its members."""
    team_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(team_id)
    team_doc = team_ref.get()
    if not team_doc.exists:
        raise HTTPException(status_code=404, detail="Team not found")

    # Unlink members from the team
    team_data = team_doc.to_dict()
    for member_id in team_data.get("members", []):
        try:
            db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(member_id).update({
                "teamId": None,
                "teamName": None,
                "status": TeamStatus.FREE.value
            })
        except Exception:
            pass
            
    team_ref.delete()
    return None


@router.post("/rescue-ops/teams/{team_id}/assign", response_model=RescueTeamResponse)
def assign_team(team_id: str, latitude: float = Body(...), longitude: float = Body(...)):
    """Assigns a free team to a specific location."""
    team_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(team_id)
    team_doc = team_ref.get()
    if not team_doc.exists:
        raise HTTPException(status_code=404, detail="Team not found")

    if team_doc.to_dict().get("status") != TeamStatus.FREE.value:
        raise HTTPException(status_code=400, detail="Team is not available for assignment.")

    team_ref.update({
        "status": TeamStatus.ASSIGNED.value,
        "assignedLatitude": latitude,
        "assignedLongitude": longitude
    })

    # send sms to all team members with the assigned location details
    # get all team members
    try:
        team_data = team_ref.get().to_dict()
        member_ids = team_data.get("members", [])
        for member_id in member_ids:
            # get phone number of the member
            rescuer_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(member_id)
            rescuer_doc = rescuer_ref.get()
            if not rescuer_doc.exists:
                continue
            rescuer_data = rescuer_doc.to_dict()
            phone_number = rescuer_data.get("phone")
            print(":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::")
            address = get_address_from_latlong(latitude, longitude)
            print(":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::")
            message = f'DISASTERLINKx9050 {{"msg": "99", "lat": {latitude}, "lon": {longitude}, "address": "{address}"}}'
            send_sms(phone_number, message)
            # print(address)

            # user list of all victims to be send in sms:
            # get users within 5km radius of the assigned location
            victims_ref = db.collection(settings.FIREBASE_COLLECTION_VICTIMS).where("isActive", "==", True)
            victims_docs = victims_ref.stream()
            victims = []
            for victim in victims_docs:
                victim_data = victim.to_dict()
                if victim_data.get("isActive") is True:
                    victims.append(victim_data)
            nearest_victims = find_nearest_victims(latitude, longitude, victims)
            if not nearest_victims:
                continue

            # Send the list of nearest victims to the rescuer via SMS
            for victim in nearest_victims:
                victim_list_str = f'{victim.get("phoneNumber","N/A")},{victim.get("name","N/A")},{victim.get("dateOfBirth","N/A")},{victim.get("status","N/A")};'
                victim_list_message = f'DISASTERLINKx9050 {{"msg": "98", "victim": "{victim_list_str}"}}'
                send_sms(phone_number, victim_list_message)
                print(victim_list_message)
            # victim_list_message = f'DISASTERLINKx9050 {{"msg": "98", "victims": "{victim_list_str}"}}'

            

    except Exception as e:
        print(f"Error sending SMS to team members: {e}")

    return _construct_team_response(team_ref.get())


@router.post("/rescue-ops/teams/{team_id}/unassign", response_model=RescueTeamResponse)
def unassign_team(team_id: str):
    """Unassigns a team by setting its assigned location to null and changing its status to FREE."""
    team_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(team_id)
    team_doc = team_ref.get()
    
    if not team_doc.exists:
        raise HTTPException(status_code=404, detail="Team not found")
    
    if team_doc.to_dict().get("status") != TeamStatus.ASSIGNED.value:
        raise HTTPException(status_code=400, detail="Team is not currently assigned.")
    
    team_ref.update({
        "status": TeamStatus.FREE.value,
        "assignedLatitude": None,
        "assignedLongitude": None
    })
    
    return _construct_team_response(team_ref.get())








# sms rescue ops 
@router.get("/rescue-ops/send-victim-list")
# def sendVictimListToTeamMember(rescuerId: str):
def sendVictimListToTeamMember():
    rescuerId = "3tboDV5EDgSGnSInKv8l"
    # first get the assigned team of that member, then get team assigned location in lat long
    # use haversine distance with between assigned location and all victims location to get nearest victims (range of 5km)
    # send that list to the rescuer using sms

    # get team of that member
    doc_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).document(rescuerId)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Rescuer not found")
    rescuer_data = doc.to_dict()
    teamId = rescuer_data.get("teamId")
    if not teamId:
        raise HTTPException(status_code=400, detail="Rescuer is not assigned to any team")
    

    # get team assigned location
    team_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).document(teamId)
    team_doc = team_ref.get()
    if not team_doc.exists:
        raise HTTPException(status_code=404, detail="Team not found")
    team_data = team_doc.to_dict()
    assigned_lat = team_data.get("assignedLatitude")
    assigned_lon = team_data.get("assignedLongitude")
    if assigned_lat is None or assigned_lon is None:
        raise HTTPException(status_code=400, detail="Team is not assigned to any location")
    
    # get all victims
    victims_ref = db.collection(settings.FIREBASE_COLLECTION_VICTIMS).where("isActive", "==", True)
    victims_docs = victims_ref.stream()
    victims = []
    for victim in victims_docs:
        victim_data = victim.to_dict()
        if victim_data.get("isActive") is True:
            victims.append(victim_data)

   # find nearest victims
    nearest_victims = find_nearest_victims(assigned_lat, assigned_lon, victims)
    if not nearest_victims:
       raise HTTPException(status_code=404, detail="No active victims found nearby")

    # send sms to the rescuer with the list of nearest victims
    ### LEFT 
    print(f"Sending SMS to rescuer {rescuerId} with nearest victims: {nearest_victims}")
    # return in Http response



    # parse into a particular format



    return {"message": f"SMS sent to rescuer {rescuerId} with nearest victims", "victims": nearest_victims}



def find_nearest_victims(lat: float, lon: float, victims: list, radius_km: float = 5.0) -> list:
    def haversine(lat1, lon1, lat2, lon2):
        # Convert decimal degrees to radians 
        lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
        # Haversine formula 
        dlon = lon2 - lon1 
        dlat = lat2 - lat1 
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * asin(sqrt(a)) 
        r = 6371 # Radius of earth in kilometers
        return c * r

    nearby_victims = []
    for victim in victims:
        v_lat = victim.get("latitude")
        v_lon = victim.get("longitude")
        if v_lat is not None and v_lon is not None:
            distance = haversine(lat, lon, v_lat, v_lon)
            if distance <= radius_km:
                nearby_victims.append(victim)
    
    return nearby_victims


























import struct
import base64

def pack_victims_to_binary_base64(victim_list: list) -> str:
    """
    Packs a list of victim dictionaries into a compact binary format and
    encodes it as a Base64 string for sending via SMS.
    
    Expected format for each victim dict:
    {
        "phone": "123456789012",  # String of 12 digits
        "name": "JaneDoe",
        "age": 30
    }
    """
    all_packed_records = []

    for victim in victim_list:
        # --- 1. Safely extract and sanitize data ---
        # Convert the phone string to an integer. Default to 0 if missing/invalid.
        try:
            phone_int = int(victim.get("phone", 0))
        except (ValueError, TypeError):
            phone_int = 0
            
        # Get the name. Default to an empty string if missing.
        name_str = victim.get("name", "")
        
        # Get the age. Default to 0 if missing.
        age_int = victim.get("age", 0)

        # --- 2. Encode the name and get its length ---
        name_bytes = name_str.encode('utf-8')
        name_length = len(name_bytes)
        
        # --- 3. Define the binary format for this record ---
        # > = Big-Endian (network standard)
        # Q = Unsigned long long (8 bytes) for the phone number
        # B = Unsigned char (1 byte) for the name length
        # {name_length}s = The variable-length name string itself
        # B = Unsigned char (1 byte) for the age
        format_string = f'> Q B {name_length}s B'

        # --- 4. Pack the data into a binary chunk ---
        try:
            packed_record = struct.pack(format_string, phone_int, name_length, name_bytes, age_int)
            all_packed_records.append(packed_record)
        except struct.error as e:
            print(f"Skipping record due to packing error: {e}. Data: {victim}")
            continue

    # --- 5. Join all chunks and encode to Base64 ---
    final_payload_bytes = b"".join(all_packed_records)
    final_payload_base64 = base64.b64encode(final_payload_bytes).decode('utf-8')
    
    return final_payload_base64










from geopy.geocoders import Nominatim

from geopy.geocoders import Nominatim
from geopy.exc import GeocoderTimedOut, GeocoderServiceError



def get_address_from_latlong(lat, long):
    """
    Gets a formatted address from latitude and longitude using Nominatim.
    Includes error handling for network issues and timeouts.
    """
    if lat is not None and long is not None:
        lat = round(float(lat), 4)
        long = round(float(long), 4)
    try:
        geolocator = Nominatim(user_agent="disasterlink_app_v1") # Use a descriptive user agent
        location = geolocator.reverse((lat, long), language="en", timeout=10)
        
        if location and location.address:
            # Truncate address to max 55 characters
            address = location.address
            if len(address) > 55:
                address = address[:52] + "..."
            return address
        else:
            return "Address not found for the given coordinates."
            
    except GeocoderTimedOut:
        return "Error: Geocoding service timed out."
    except GeocoderServiceError as e:
        return f"Error: Geocoding service error: {e}"
    except Exception as e:
        return f"An unexpected error occurred: {e}"













from datetime import datetime




def calculate_age(dob_str: str) -> int:
    """Calculates age from a 'YYYY-MM-DD' formatted string."""
    try:
        birth_date = datetime.strptime(dob_str, "%Y-%m-%d")
        today = datetime.today()
        return today.year - birth_date.year - ((today.month, today.day) < (birth_date.month, birth_date.day))
    except (ValueError, TypeError):
        # Return a default age if format is wrong or dob_str is None
        return 30 

# --- Helper function to calculate distance ---
def haversine(lat1, lon1, lat2, lon2):
    """Calculates the distance between two points on Earth in kilometers."""
    if any(v is None for v in [lat1, lon1, lat2, lon2]):
        return float('inf') # Return infinite distance if location is unknown
    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
    dlon = lon2 - lon1 
    dlat = lat2 - lat1 
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a)) 
    r = 6371 # Radius of earth in kilometers
    return c * r

# --- Helper to fetch rescuer data efficiently ---
def _fetch_rescuers_data(rescuer_ids: list) -> dict:
    """Helper function to fetch rescuer data in batches."""
    if not rescuer_ids:
        return {}
    
    rescuers_map = {}
    # Firestore 'in' query supports up to 30 elements
    for i in range(0, len(rescuer_ids), 30):
        batch_ids = rescuer_ids[i:i+30]
        rescuers_query = db.collection(settings.FIREBASE_COLLECTION_RESCUERS).where("id", "in", batch_ids).stream()
        for rescuer in rescuers_query:
            rescuer_data = rescuer.to_dict()
            rescuers_map[rescuer_data["id"]] = rescuer_data
    return rescuers_map

# --- Main Auto-Assignment Function ---
@router.post("/rescue-ops/incidents/{incident_id}/auto-assign", response_model=RescueTeamResponse)
def auto_assign_team_to_incident(incident_id: str):
    """
    Automatically assigns the most optimal team to an incident based on a scoring algorithm.
    The score considers distance, number of victims, victim vulnerability, and team size.
    """
    # 1. Fetch Incident and All Active Data
    incident_ref = db.collection("incidents").document(incident_id)
    incident_doc = incident_ref.get()
    if not incident_doc.exists:
        raise HTTPException(status_code=404, detail=f"Incident with ID {incident_id} not found.")
    incident_data = incident_doc.to_dict()
    incident_location = incident_data.get("location")
    if not incident_location:
        raise HTTPException(status_code=400, detail="Incident has no location data.")

    teams_ref = db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS)
    available_teams_docs = teams_ref.where("status", "==", TeamStatus.FREE.value).stream()
    available_teams = [t.to_dict() for t in available_teams_docs]
    if not available_teams:
        raise HTTPException(status_code=404, detail="No free teams available for assignment.")

    victims_ref = db.collection(settings.FIREBASE_COLLECTION_VICTIMS)
    active_victims_docs = victims_ref.where("isActive", "==", True).stream()
    active_victims = [v.to_dict() for v in active_victims_docs]

    # 2. Cluster Victims for the Incident
    incident_victims = []
    for victim in active_victims:
        dist = haversine(incident_location['latitude'], incident_location['longitude'], victim.get('latitude'), victim.get('longitude'))
        if dist <= 1.0: # Cluster victims within a 1km radius
            incident_victims.append(victim)
    
    if not incident_victims:
        raise HTTPException(status_code=404, detail="No active victims found within 1km of the incident location.")

    # 3. Calculate Victim Urgency Score for the Incident
    total_vulnerability_points = 0
    for victim in incident_victims:
        points = 0
        if victim.get("status") == "Critical": points += 10
        elif victim.get("status") == "Needs Help": points += 5
        else: points += 1
        
        dob_datetime = victim.get("dateOfBirth")
        if isinstance(dob_datetime, datetime):
            age = calculate_age(dob_datetime.strftime('%Y-%m-%d'))
            if age < 15 or age > 60: points += 4
            else: points += 1
        else:
            points += 1

        total_vulnerability_points += points

    num_victims = len(incident_victims)
    
    # 4. Calculate Scores for Each Team
    team_scores = []
    all_leader_ids = [t.get("leader") for t in available_teams if t.get("leader")]
    leaders_data = _fetch_rescuers_data(all_leader_ids)

    for team in available_teams:
        leader_id = team.get("leader")
        leader_data = leaders_data.get(leader_id)
        if not leader_data or leader_data.get("latitude") is None:
            continue

        distance = haversine(leader_data['latitude'], leader_data['longitude'], incident_location['latitude'], incident_location['longitude'])
        team_size = len(team.get("members", [])) + 1
        suitability = min(team_size / num_victims, 1.5)
        
        team_scores.append({
            "teamId": team["teamId"],
            "distance": distance,
            "suitability": suitability
        })

    if not team_scores:
        raise HTTPException(status_code=404, detail="No available teams have location data.")

    # 5. Normalize and Calculate Final Score
    max_dist = max(s['distance'] for s in team_scores) if team_scores else 1
    max_suitability = max(s['suitability'] for s in team_scores) if team_scores else 1
    
    final_scores = []
    for score_card in team_scores:
        dist_score = 1 - (score_card['distance'] / max_dist) if max_dist > 0 else 0
        suitability_score = score_card['suitability'] / max_suitability if max_suitability > 0 else 0

        # Weighted score calculation
        final_score = (0.7 * dist_score) + (0.3 * suitability_score)
        final_scores.append({"teamId": score_card['teamId'], "score": final_score})

    # 6. Select Best Team and Assign    
    best_team = max(final_scores, key=lambda x: x['score'])
    best_team_id = best_team['teamId']

    incident_ref.update({"status": "inprogress"})
    
    # Call the existing assignment function
    return assign_team(best_team_id, incident_location['latitude'], incident_location['longitude'])

