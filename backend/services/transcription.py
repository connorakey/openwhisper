import platform
import tempfile
import os
import base64

def _init_whisper():
    """Initialize the best Whisper engine based on the available hardware."""
    system = platform.system()
    machine = platform.machine()

    # Try MLX model for Apple Silicon
    if system == 'Darwin' and machine == 'arm64':
        try:
            import mlx_whisper
            print("Using mlx_whisper for Apple Silicon")
            return "mlx", None
        except ImportError:
            print("mlx_whisper not available, falling back to torch")

    # Use faster_whisper for other systems
    import torch
    from faster_whisper import WhisperModel
    device = "cuda" if torch.cuda.is_available() else "cpu"
    compute_type = "float16" if device == "cuda" else "int8"

    print("Using faster_whisper with device:", device, "and compute_type:", compute_type)

    model = WhisperModel("large-v3", device=device, compute_type=compute_type)
    return "faster_whisper", model

ENGINE, MODEL = _init_whisper()


def transcribe_audio(audio_path: str) -> str:
    """Transcribe audio file to text"""
    if ENGINE == "mlx":
        import mlx_whisper
        result = mlx_whisper.transcribe(
            audio_path,
            path_or_hf_repo="mlx-community/whisper-large-v3-mlx"
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