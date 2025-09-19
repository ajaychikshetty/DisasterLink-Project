from fastapi import APIRouter, HTTPException
from schemas.auth import LoginRequest, LoginResponse

router = APIRouter()  # no prefix → /login directly

@router.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    if request.username == "sairaj" and request.password == "sairaj123":
        return {"status": "success", "idToken": "dummy-token"}
    else:
        raise HTTPException(status_code=401, detail="Invalid credentials")
