import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from firebase import cred, db
from fastapi.middleware.cors import CORSMiddleware
from routers import users, incidents, rescue_ops, shelters, maps, communication, rescuers, sms, messages, auth, autoassign

app = FastAPI(
    title="Disaster Management API",
    description="API for coordinating disaster relief and rescue operations.",
    version="1.0.0"
)




# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    # allow_origins=["*"],  # Change this to restrict origins
    allow_credentials=True,
    allow_origins=["http://localhost:5173"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(users.router)
app.include_router(incidents.router)
app.include_router(rescue_ops.router)
app.include_router(shelters.router)
app.include_router(maps.router)
app.include_router(communication.router)
app.include_router(rescuers.router)
app.include_router(sms.router)
app.include_router(messages.router)
app.include_router(auth.router)
app.include_router(autoassign.router)



@app.get("/", tags=["Root"])
def read_root():
    return {"message": "Welcome to the Disaster Management API"}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=5000, reload=True)
    
