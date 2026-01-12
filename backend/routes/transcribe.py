import os

from dotenv import load_dotenv
from fastapi import APIRouter, Header, HTTPException
from schemas import TranscribeRequest, TranscribeResponse
from services.text_cleaner import remove_disfluencies
from services.transcription import transcribe_base64

load_dotenv()

router = APIRouter()

EXPECTED_AUTH_TOKEN = os.getenv("API_AUTH_TOKEN")


@router.post("/transcribe")
async def transcribe(request: TranscribeRequest, authorization: str = Header(None)):
    # Validate authorization header
    if not authorization or authorization != EXPECTED_AUTH_TOKEN:
        raise HTTPException(
            status_code=401,
            detail="Unauthorized: Invalid or missing authorization token",
        )

    try:
        # Transcribe with Whisper
        raw_transcript = transcribe_base64(request.audio_base64)

        # Clean with LLM
        cleaned_transcript = remove_disfluencies(raw_transcript)

        return TranscribeResponse(transcript=cleaned_transcript)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
