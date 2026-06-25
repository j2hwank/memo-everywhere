"""
Whisper proxy endpoint (REQ-B-006):
  POST /voice/transcribe — accepts audio bytes, returns transcription text.

# @MX:WARN: [AUTO] External OpenAI API call — cost/failure/timeout risk.
# @MX:REASON: Whisper API is billed per second of audio; failures here cost money
#             and are not retried automatically. Monitor usage.
"""
from fastapi import APIRouter, Depends, HTTPException, Request

from app.api.routes.deps import get_current_user
from app.models.user import User
from app.core.config import settings

router = APIRouter()


async def transcribe_audio(audio_bytes: bytes, filename: str = "audio.webm") -> str:
    """
    Forward audio to OpenAI Whisper API and return transcript text.

    # @MX:WARN: [AUTO] Calls external OpenAI API — subject to rate limits and billing.
    # @MX:REASON: Any caller of this function incurs external API cost per invocation.
    """
    from openai import AsyncOpenAI
    import io

    client = AsyncOpenAI(api_key=settings.openai_api_key)
    audio_file = io.BytesIO(audio_bytes)
    audio_file.name = filename

    response = await client.audio.transcriptions.create(
        model="whisper-1",
        file=audio_file,
    )
    return response.text


@router.post("/transcribe")
async def voice_transcribe(
    request: Request,
    current_user: User = Depends(get_current_user),
):
    """AC-6: Accept raw audio bytes and return Whisper transcription."""
    audio_bytes = await request.body()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Audio data is required")

    content_type = request.headers.get("content-type", "audio/webm")
    extension_map = {
        "audio/webm": "audio.webm",
        "audio/mp4": "audio.mp4",
        "audio/wav": "audio.wav",
        "audio/mpeg": "audio.mp3",
    }
    filename = extension_map.get(content_type.split(";")[0], "audio.webm")

    text = await transcribe_audio(audio_bytes, filename)
    return {"text": text}
