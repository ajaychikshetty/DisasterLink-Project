# config.py

from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Disaster Management API"
    VERSION: str = "1.0.0"
    FIREBASE_COLLECTION_USERS: str = "users"
    FIREBASE_COLLECTION_RESCUERS: str = "rescuers"
    FIREBASE_COLLECTION_RESCUE_TEAMS: str = "rescue_teams"
    FIREBASE_COLLECTION_SHELTERS: str = "shelters"
    FIREBASE_COLLECTION_LOGS: str = "rescue_logs"
    FIREBASE_COLLECTION_INCIDENTS: str = "incidents"
    FIREBASE_COLLECTION_MESSAGES: str = "Messages"
    # TWILIO_ACCOUNT_SID: str
    # TWILIO_AUTH_TOKEN: str
    # TWILIO_FROM_NUMBER: str

    # class Config:
    #     env_file = ".env"



settings = Settings()