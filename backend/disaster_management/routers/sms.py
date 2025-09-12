# from utils.sms import send_sms
import datetime
import re

from flask import json
import requests
from fastapi import APIRouter, HTTPException, Form
from fastapi.responses import PlainTextResponse
from services.sms_handler import handle_sms_command
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import BaseModel
from typing import List
from firebase import db, firestore
import math



router = APIRouter(prefix="/api", tags=["SMS"])

outgoing_sms_queue: List[dict] = []

class SMSRequest(BaseModel):
    number: str
    msg: str
router = APIRouter(prefix="/api", tags=["SMS"])

@router.post("/queue_sms")
async def queue_sms(sms: SMSRequest):
    outgoing_sms_queue.routerend({"number": sms.number, "msg": sms.msg})
    return {"status": "queued", "to": sms.number, "msg": sms.msg}

@router.get("/get_sms")
async def get_sms():
    if outgoing_sms_queue:
        return outgoing_sms_queue.pop(0)
    return {"status": "empty"}



# CALCULATING DISTANCEEEE

def haversine_distance(lat1, lon1, lat2, lon2):
    R = 6371  # km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R*c

def get_nearest_shelters(user_location, top_n=1): 
    db = firestore.client()
    shelters_ref = db.collection('shelters')
    
    nearest_shelters = []
    
    for doc in shelters_ref.stream():
        data = doc.to_dict()
        # Check if 'lat' and 'lon' exist
        if 'latitude' in data and 'longitude' in data:
            dist = haversine_distance(
                user_location.latitude, user_location.longitude,
                data['latitude'], data['longitude']
            )
            data['distance_km'] = dist
            data['id'] = doc.id
            nearest_shelters.append(data)
        else:
            print(f"Skipping {doc.id}, missing lat/lon")
    
    # Sort by distance
    nearest_shelters.sort(key=lambda x: x['distance_km'])
    return nearest_shelters[:top_n]


def send_REPLY(to: str, lat: float, lon: float, type: int):
    match type:
        case 102:
            base_msg = "DISASTERLINKx9040 101 !\n"

            # Construct user location
            user_loc = firestore.GeoPoint(lat, lon)
            top3 = get_nearest_shelters(user_loc)

            # Format shelters info as readable plain text
            shelters_lines = []
            for shelter in top3:
                line = f"{shelter['name']} {round(shelter['distance_km'], 2)} km, {shelter.get('latitude','N/A')},{shelter.get('longitude','N/A')}, {shelter.get('contactNumber','N/A')}"
                shelters_lines.append(line)

            # Combine into final message
            final_msg = base_msg + "Nearest shelters:\n" + "\n".join(shelters_lines)
            print(final_msg)

            # Send SMS
            send_sms(to, final_msg)

            # Optionally, return dict for logging
            return {
                "msg": base_msg.strip(),
                "nearest_shelters": top3
            }
            


@router.post("/receive_sms")
async def receive_sms(data: dict):
    print(f"📥 Incoming SMS from {data.get('from')}: {data.get('msg')}")

    # Extract fields from incoming data
    message_text = data.get("msg", "")
    sender = data.get("from", "")
    match = re.search(r'\{.*\}$', message_text)   # matches from { to end of string
    if match:
        json_str = match.group(0)
        data = json.loads(json_str)
        latitude=data['lat']
        longitude=data['lon']

        # Create GeoPoint object
        location = firestore.GeoPoint(latitude, longitude) if latitude and longitude else None

        # Prepare document data
        doc_data = {
            "Message": data['msg'],
            "Sender": sender,
            "Timestamp": firestore.SERVER_TIMESTAMP ,
            "Type": int(data['sos']),
            "Battery": data['bat'],
            "location": location
        }

        # Add document to 'Messages' collection
        db.collection("Messages").add(doc_data)
        send_REPLY(sender,latitude,longitude,int(data['sos']))
        return {"status": "received"}
    else:
        print("No JSON found in the message.")


    

    # return {"status": "received"}

# ✅ Simple HTML Form to send SMS
@router.get("/test-sms", response_class=HTMLResponse)
async def form_page():
    return """
    <html>
        <head><title>SMS Gateway</title></head>
        <body>
            <h2>📡 Send SMS</h2>
            <form action="/api/send_form" method="post">
                <label>Phone Number:</label>
                <input type="text" name="number" required><br><br>
                <label>Message:</label>
                <textarea name="msg" rows="4" cols="30" required></textarea><br><br>
                <button type="submit">Send SMS</button>
            </form>
        </body>
    </html>
    """

@router.post("/send_form")
async def send_form(number: str = Form(...), msg: str = Form(...)):
    outgoing_sms_queue.append({"number": number, "msg": msg})
    return RedirectResponse("/api/test-sms", status_code=303)

API_URL = "https://yourowncustommessagingservice.onrender.com/queue_sms"

def send_sms(to: str, msg: str) -> dict:
    """
    Queue an SMS message.

    Args:
        to (str): Recipient phone number (with country code, e.g., +91XXXXXXXXXX)
        msg (str): Message text

    Returns:
        dict: Response from the API
    """
    payload = {
        "number": to,
        "msg": msg
    }
    try:
        response = requests.post(API_URL, json=payload)
        response.raise_for_status() 
        print("MSSG SENT") # Raise error if HTTP status != 200
        return response.json()
    except requests.RequestException as e:
        print("Error sending SMS:", e)
        return {"status": "error", "error": str(e)}



class DisasterAlertRequest(BaseModel):
    disaster_name: str
    numbers: List[str]  # force list of numbers

@router.post("/disaster_alert")
async def sendAlert(alert: DisasterAlertRequest):
    """
    Receives a disaster name and list of phone numbers,
    sends an alert message to all numbers via send_sms.
    """
    msg = f"⚠️ Disaster Alert: {alert.disaster_name}\nStay safe and follow instructions."

    results = []
    for num in alert.numbers:
        res = send_sms(num, msg)
        results.append({"number": num, "result": res})

    return {
        "status": "completed",
        "disaster_name": alert.disaster_name,
        "message": msg,
        "results": results
    }
