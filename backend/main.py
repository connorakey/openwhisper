# backend/main.py
from fastapi import FastAPI
from routes import health_router, transcribe_router

app = FastAPI()

# Include all API routes
app.include_router(transcribe_router)
app.include_router(health_router)
