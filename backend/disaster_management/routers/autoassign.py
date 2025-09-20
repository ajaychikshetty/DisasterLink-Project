from fastapi import APIRouter, HTTPException
from firebase import db
from datetime import datetime
import math
from fastapi import Query

router = APIRouter(prefix="/api/assign", tags=["Assignment"])

# Haversine formula
def haversine(lat1, lon1, lat2, lon2):
    R = 6371  # Earth radius in km
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (math.sin(d_lat / 2) ** 2 +
         math.cos(math.radians(lat1)) *
         math.cos(math.radians(lat2)) *
         math.sin(d_lon / 2) ** 2)
    return 2 * R * math.asin(math.sqrt(a))

# Calculate age
def calculate_age(birthday_str):
    try:
        birthday = datetime.fromisoformat(birthday_str)
        today = datetime.now()
        return today.year - birthday.year - (
            (today.month, today.day) < (birthday.month, birthday.day)
        )
    except Exception:
        return None

@router.post("/")
async def auto_assign_victims_debug_fixed():
    if not db:
        raise HTTPException(500, "Database not connected.")

    victims_ref = db.collection("victims")
    teams_ref = db.collection("rescue_teams")

    victims = [v.to_dict() | {"id": v.id} for v in victims_ref.stream()]
    teams = [t.to_dict() | {"id": t.id} for t in teams_ref.stream()]

    # Only teams with status == "Assigned"
    available_teams = [t for t in teams if t.get("status") == "Assigned"]

    if not available_teams:
        return {
            "assigned": [],
            "count": 0,
            "message": "No available teams with status 'Assigned'",
            "debug": {"total_teams": len(teams)}
        }

    enriched_victims = []
    skipped_victims = []

    for victim in victims:
        v_id = victim["id"]
        v_lat = victim.get("latitude")
        v_lon = victim.get("longitude")

        if v_lat is None or v_lon is None:
            skipped_victims.append({"victimId": v_id, "reason": "Missing coordinates"})
            continue

        age = calculate_age(victim.get("birthday"))
        priority = 1 if (age is not None and (age < 15 or age > 50)) else 2

        nearest_team = None
        nearest_dist = float("inf")

        for team in available_teams:
            t_lat = team.get("assignedLatitude")  # Fixed field
            t_lon = team.get("assignedLongitude") # Fixed field
            if t_lat is None or t_lon is None:
                continue

            dist = haversine(v_lat, v_lon, t_lat, t_lon)
            if dist <= 5 and dist < nearest_dist:
                nearest_team = team
                nearest_dist = dist

        if nearest_team:
            enriched_victims.append({
                **victim,
                "priority": priority,
                "nearest_team": nearest_team,
                "nearest_dist": nearest_dist
            })
        else:
            skipped_victims.append({"victimId": v_id, "reason": "No team within 5 km"})

    enriched_victims.sort(key=lambda v: (v["priority"], v["nearest_dist"]))

    assigned = []
    for victim in enriched_victims:
        team = victim["nearest_team"]
        victims_ref.document(victim["id"]).update({
            "assignedTeamId": team["id"]
        })
        assigned.append({
            "victimId": victim["id"],
            "teamId": team["id"],
            "distance_km": round(victim["nearest_dist"], 2),
            "priority": victim["priority"]
        })

    return {
        "assigned": assigned,
        "count": len(assigned),
        "skipped": skipped_victims,
        "debug": {
            "total_victims": len(victims),
            "available_teams": len(available_teams)
        }
    }
