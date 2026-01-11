from pydantic import BaseModel


class TranscribeRequest(BaseModel):
    audio_base64: str


class TranscribeResponse(BaseModel):
    raw_transcript: str
    cleaned_transcript: str

