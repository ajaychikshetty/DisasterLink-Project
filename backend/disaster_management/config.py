from pydantic_settings import BaseSettings
from pathlib import Path

class Settings(BaseSettings):
    # App info
    PROJECT_NAME: str = "Disaster Management API"
    VERSION: str = "1.0.0"

    # Firebase
    FIREBASE_KEY_PATH: Path = Path("serviceAccountKey.json")  # path to your service account key
    # FIREBASE_DATABASE_URL: str = "https://your-project-id.firebaseio.com"  # for Realtime DB (optional)

    # Firestore collections
    FIREBASE_COLLECTION_USERS: str = "users"
    FIREBASE_COLLECTION_RESCUERS: str = "rescuers"
    FIREBASE_COLLECTION_RESCUE_TEAMS: str = "rescue_teams"
    FIREBASE_COLLECTION_SHELTERS: str = "shelters"
    FIREBASE_COLLECTION_LOGS: str = "rescue_logs"
    FIREBASE_COLLECTION_INCIDENTS: str = "incidents"
    FIREBASE_COLLECTION_MESSAGES: str = "Messages"
    FIREBASE_COLLECTION_Admins: str = "admins"

    # Twilio (optional)
    # TWILIO_ACCOUNT_SID: str
    # TWILIO_AUTH_TOKEN: str
    # TWILIO_FROM_NUMBER: str

    # class Config:
    #     env_file = ".env"  # load variables from .env file if present
    #     env_file_encoding = "utf-8"

# Instantiate settings object
settings = Settings()
