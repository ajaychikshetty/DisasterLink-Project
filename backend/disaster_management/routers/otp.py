# app/otp.py
import random, time
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from .sms_queue import sms_queue

router = APIRouter()

# In-memory OTP store: { phone_number: {otp: str, expires: timestamp} }
otp_store = {}

class PhoneRequest(BaseModel):
    phone_number: str

class VerifyRequest(BaseModel):
    phone_number: str
    otp: str

@router.post("/request_otp")
def request_otp(req: PhoneRequest):
    otp = str(random.randint(100000, 999999))  # 6 digit OTP
    expiry = time.time() + 300  # 5 minutes

    otp_store[req.phone_number] = {"otp": otp, "expires": expiry}

    # enqueue SMS for Flutter gateway
    sms_queue.append({"number": req.phone_number, "msg": f"Your OTP is {otp}"})

    return {"status": "ok", "message": f"OTP sent to {req.phone_number}"}

@router.post("/verify_otp")
def verify_otp(req: VerifyRequest):
    record = otp_store.get(req.phone_number)

    if not record:
        raise HTTPException(status_code=400, detail="No OTP requested")

    if time.time() > record["expires"]:
        del otp_store[req.phone_number]
        raise HTTPException(status_code=400, detail="OTP expired")

    if req.otp != record["otp"]:
        raise HTTPException(status_code=400, detail="Invalid OTP")

    del otp_store[req.phone_number]  # OTP is one-time use
    return {"status": "ok", "message": "OTP verified"}
