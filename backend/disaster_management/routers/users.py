from fastapi import APIRouter, HTTPException
from firebase import db
from config import settings
from schemas.user import UserCreate, UserResponse
from utils.common import calculate_age

router = APIRouter(prefix="/api/users", tags=["Users"])

@router.post("", response_model=UserResponse)
def create_user(user: UserCreate):
    try:
        age = calculate_age(user.dob)
        doc_ref = db.collection(settings.FIREBASE_COLLECTION_USERS).document()
        user_data = {
            "userId": doc_ref.id,
            "name": user.name,
            "dob": user.dob,
            "age": age,
            "gender": user.gender,
            "contactNo": user.contactNo,
            "city": user.city,
            "status": "Active",
            "bloodGroup": user.bloodGroup,
            "location": user.location.dict(),
        }
        doc_ref.set(user_data)
        return user_data
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/{userId}", response_model=UserResponse)
def get_user(userId: str):
    doc = db.collection(settings.FIREBASE_COLLECTION_USERS).document(userId).get()
    if not doc.exists:
        print("inside get user")
        raise HTTPException(status_code=404, detail="User not found")
    return doc.to_dict()

@router.get("/by-phone/{phone_number}", response_model=UserResponse)
def get_user_by_phone(phone_number: str):
    users_ref = db.collection(settings.FIREBASE_COLLECTION_USERS)
    query = users_ref.where("contactNo", "==", phone_number).limit(1).stream()
    user_doc = next(query, None)
    print(query)
    print(user_doc.to_dict() if user_doc else "No user found")
    if user_doc and user_doc.exists:
        return user_doc.to_dict()
    raise HTTPException(status_code=404, detail="User not found")

@router.put("/{userId}")
def update_user(userId: str, payload: dict):
    doc_ref = db.collection(settings.FIREBASE_COLLECTION_USERS).document(userId)
    if not doc_ref.get().exists:
        print("inside update user")
        raise HTTPException(status_code=404, detail="User not found")
    # Update age if dob is present in payload
    if "dob" in payload:
        payload["age"] = calculate_age(payload["dob"])
    doc_ref.update(payload)
    return doc_ref.get().to_dict()

@router.delete("/{userId}")
def delete_user(userId: str):
    doc_ref = db.collection(settings.FIREBASE_COLLECTION_USERS).document(userId)
    if not doc_ref.get().exists:
        print("inside delete user")
        raise HTTPException(status_code=404, detail="User not found")
    doc_ref.delete()
    return {"message": "User deleted successfully"}


@router.get("", response_model=list[UserResponse])
def list_users():
    docs = db.collection(settings.FIREBASE_COLLECTION_USERS).stream()
    users = [doc.to_dict() for doc in docs]
    return users



@router.get("", response_model=list[UserResponse])
def list_users(shelterId: str | None = None):
    docs = db.collection(settings.FIREBASE_COLLECTION_USERS).stream()
    users = [doc.to_dict() for doc in docs]

    if shelterId:
        # fetch the shelter
        shelter_doc = db.collection(settings.FIREBASE_COLLECTION_SHELTERS).document(shelterId).get()
        if not shelter_doc.exists:
            raise HTTPException(status_code=404, detail="Shelter not found")

        member_ids = shelter_doc.to_dict().get("rescuedMembers", [])
        users = [u for u in users if u["userId"] in member_ids]

    return users
