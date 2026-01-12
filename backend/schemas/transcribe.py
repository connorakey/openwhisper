from pydantic import BaseModel


class TranscribeRequest(BaseModel):
    audio_base64: str


class TranscribeResponse(BaseModel):
    transcript: str
