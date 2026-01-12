from fastapi import APIRouter, HTTPException
from services.transcription import transcribe_base64
from schemas import TranscribeRequest, TranscribeResponse
from services.text_cleaner import remove_disfluencies

router = APIRouter()


@router.post("/transcribe")
async def transcribe(request: TranscribeRequest):
    try:
        # Transcribe with Whisper
        raw_transcript = transcribe_base64(request.audio_base64)

        # TODO: Clean with LLM
        cleaned_transcript = remove_disfluencies(raw_transcript)

        return TranscribeResponse(
            transcript=cleaned_transcript
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

