# backend/main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transcribe import transcribe_base64

app = FastAPI()


class TranscribeRequest(BaseModel):
    audio_base64: str


class TranscribeResponse(BaseModel):
    raw_transcript: str
    cleaned_transcript: str


@app.post("/transcribe")
async def transcribe(request: TranscribeRequest):
    try:
        # Transcribe with Whisper
        raw_transcript = transcribe_base64(request.audio_base64)

        # TODO: Clean with LLM
        cleaned_transcript = raw_transcript  # For now

        return TranscribeResponse(
            raw_transcript=raw_transcript,
            cleaned_transcript=cleaned_transcript
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health():
    return {"status": "healthy"}