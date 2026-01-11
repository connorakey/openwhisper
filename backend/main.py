# backend/main.py
from fastapi import FastAPI
from routes.transcribe import router as transcribe_router
from routes.health import router as health_router

app = FastAPI()

# Include all API routes
app.include_router(transcribe_router)
app.include_router(health_router)
