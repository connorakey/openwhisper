import base64
import os
import platform
import tempfile

from dotenv import load_dotenv

load_dotenv()

transcription_provider = os.getenv("TRANSCRIPTION_PROVIDER", "local")
cloud_api_base_url = os.getenv("CLOUD_API_BASE_URL")
cloud_api_key = os.getenv("CLOUD_API_KEY")
transcription_api_base_url = os.getenv("TRANSCRIPTION_API_BASE_URL")
transcription_api_key = os.getenv("TRANSCRIPTION_API_KEY")
transcription_model_name = os.getenv("TRANSCRIPTION_MODEL_NAME", "whisper-large-v3")
transcription_temperature = os.getenv("TRANSCRIPTION_TEMPERATURE", "0")
transcription_vad_model = os.getenv("TRANSCRIPTION_VAD_MODEL", "")


def _init_whisper():
    """Initialize the best Whisper engine based on the available hardware."""
    # Skip initialization if using cloud provider
    if transcription_provider == "cloud":
        return "cloud", None

    system = platform.system()
    machine = platform.machine()

    # Try MLX model for Apple Silicon
    if system == "Darwin" and machine == "arm64":
        try:
            import mlx_whisper

            print("Using mlx_whisper for Apple Silicon")
            return "mlx", None
        except ImportError:
            print("mlx_whisper not available, falling back to torch")

    # Use faster_whisper for non apple silicon systems
    import torch
    from faster_whisper import WhisperModel

    device = "cuda" if torch.cuda.is_available() else "cpu"
    compute_type = "float16" if device == "cuda" else "int8"

    print(
        "Using faster_whisper with device:", device, "and compute_type:", compute_type
    )

    model = WhisperModel("large-v3", device=device, compute_type=compute_type)
    return "faster_whisper", model


ENGINE, MODEL = _init_whisper()


def _transcribe_cloud(audio_path: str) -> str:
    """Transcribe audio using OpenAI-compatible API (including Fireworks AI)"""
    import requests

    # Use transcription-specific API key, fallback to cloud API key
    api_key = transcription_api_key or cloud_api_key
    base_url = transcription_api_base_url or cloud_api_base_url

    if not api_key:
        raise ValueError(
            "TRANSCRIPTION_API_KEY or CLOUD_API_KEY must be set when using cloud transcription provider"
        )

    if not base_url:
        raise ValueError(
            "TRANSCRIPTION_API_BASE_URL or CLOUD_API_BASE_URL must be set when using cloud transcription provider"
        )

    # Prepare the endpoint URL
    base_url = base_url.rstrip("/")
    if not base_url.endswith("/audio/transcriptions"):
        endpoint = f"{base_url}/audio/transcriptions"
    else:
        endpoint = base_url

    # Prepare the request
    headers = {"Authorization": f"Bearer {api_key}"}

    with open(audio_path, "rb") as audio_file:
        files = {"file": audio_file}

        # Base data payload
        data = {
            "model": transcription_model_name,
            "temperature": transcription_temperature,
        }

        # Add VAD model if specified (for Fireworks AI)
        if transcription_vad_model:
            data["vad_model"] = transcription_vad_model

        response = requests.post(
            endpoint, headers=headers, files=files, data=data, timeout=180
        )
        response.raise_for_status()

        result = response.json()
        return result["text"]


def transcribe_audio(audio_path: str) -> str:
    """Transcribe audio file to text"""
    if ENGINE == "cloud":
        return _transcribe_cloud(audio_path)
    elif ENGINE == "mlx":
        import mlx_whisper

        result = mlx_whisper.transcribe(
            audio_path, path_or_hf_repo="mlx-community/whisper-large-v3-mlx"
        )
        return result["text"]
    else:
        segments, _ = MODEL.transcribe(audio_path)
        return " ".join([seg.text for seg in segments])


def transcribe_base64(audio_base64: str) -> str:
    """Transcribe base64 encoded audio"""
    # Decode base64
    audio_bytes = base64.b64decode(audio_base64)

    # Write to temp file
    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as f:
        f.write(audio_bytes)
        temp_path = f.name

    try:
        return transcribe_audio(temp_path)
    finally:
        os.unlink(temp_path)
