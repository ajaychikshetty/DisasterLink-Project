import json
from fastapi import APIRouter, Query
from firebase import db
from config import settings
from fastapi.responses import FileResponse, JSONResponse
import os
from shapely.geometry import shape, box



router = APIRouter(prefix="/api/map", tags=["Maps"])


@router.get("/coverage")
def map_coverage(
    min_lat: float = Query(..., description="Southwest corner latitude"),
    min_lon: float = Query(..., description="Southwest corner longitude"),
    max_lat: float = Query(..., description="Northeast corner latitude"),
    max_lon: float = Query(..., description="Northeast corner longitude")
):
    """
    Returns all users, rescue teams (with members), and shelters
    within the given bounding box.
    """

    def in_box(lat, lon):
        return min_lat <= lat <= max_lat and min_lon <= lon <= max_lon

    # --- Users ---
    users = []
    for u in db.collection(settings.FIREBASE_COLLECTION_USERS).stream():
        data = u.to_dict()
        loc = data.get("location", {})
        if "latitude" in loc and "longitude" in loc and in_box(loc["latitude"], loc["longitude"]):
            users.append(data)

    # --- Rescue Teams + Members ---
    rescue_teams = []
    for team in db.collection(settings.FIREBASE_COLLECTION_RESCUE_TEAMS).stream():
        team_data = team.to_dict()
        team_loc = team_data.get("location", {})
        if "latitude" in team_loc and "longitude" in team_loc and in_box(team_loc["latitude"], team_loc["longitude"]):
            # fetch team members (if they exist)
            members = []
            for m in db.collection(settings.FIREBASE_COLLECTION_RESCUE_MEMBERS).where("teamId", "==", team_data["id"]).stream():
                members.append(m.to_dict())
            team_data["members"] = members
            rescue_teams.append(team_data)

    # --- Shelters ---
    shelters = []
    for s in db.collection(settings.FIREBASE_COLLECTION_SHELTERS).stream():
        data = s.to_dict()
        loc = data.get("location", {})
        if "latitude" in loc and "longitude" in loc and in_box(loc["latitude"], loc["longitude"]):
            shelters.append(data)

    return {
        "users": users,
        "rescueTeams": rescue_teams,
        "shelters": shelters
    }


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "../static")

@router.get("/mumbai-map")
async def get_mumbai_map():
    file_path = os.path.join(STATIC_DIR, "mumbai-wards-map.geojson")
    if os.path.exists(file_path):
        return FileResponse(file_path, media_type="application/geo+json")
    return {"error": "File not found"}






@router.get("/boundaries")
def get_boundaries(zoom: int, bounds: str):
    """
    Selects a GeoJSON file based on zoom level and filters its features
    to only include those that intersect with the current map viewport.
    """
    try:
        # The bounds string from the frontend is URL-encoded JSON
        bounds_data = json.loads(bounds)
        
        # Create a bounding box from the map's corner coordinates
        bbox = box(
            bounds_data["_southWest"]["lng"],
            bounds_data["_southWest"]["lat"],
            bounds_data["_northEast"]["lng"],
            bounds_data["_northEast"]["lat"],
        )
    except (json.JSONDecodeError, KeyError) as e:
        return JSONResponse(status_code=400, content={"error": f"Invalid bounds format: {e}"})

    # --- Strategy for progressive loading ---
    if 3 <= zoom <= 5:
        file_name = "india_boundary.geojson"
    elif 6 <= zoom <= 8:
        file_name = "india_states.geojson"
    elif 9 <= zoom <= 11:
        file_name = "india_districts.geojson"
    else: # zoom 12+
        # NOTE: You don't have a city/ward file, so we use the most detailed one available.
        file_name = "india_subdistricts.geojson"
    
    file_path = os.path.join(STATIC_DIR, "geojson", file_name)
    print(f"Loading GeoJSON file: {file_path}")
    if not os.path.exists(file_path):
        return JSONResponse(status_code=404, content={"error": f"File not found: {file_name}"})

    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Filter features to only those intersecting with the current map view
    filtered_features = [
        feat for feat in data.get("features", [])
        if shape(feat["geometry"]).intersects(bbox)
    ]
    
    # Construct a new valid GeoJSON FeatureCollection
    filtered_geojson = {
        "type": "FeatureCollection",
        "features": filtered_features,
    }
    
    return JSONResponse(content=filtered_geojson)