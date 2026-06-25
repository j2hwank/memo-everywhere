"""
Phase 5 RED: Whisper proxy and share endpoint.

Tests (AC-6, AC-7):
- AC-6: POST /voice/transcribe with mocked OpenAI → returns text
- AC-7: GET /memos/{id}/share returns memo data
"""
import io
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from httpx import AsyncClient, ASGITransport


async def get_client():
    from app.main import app
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def register_and_login(client: AsyncClient, email: str):
    await client.post("/auth/register", json={"email": email, "password": "Pass123!"})
    resp = await client.post("/auth/login", json={"email": email, "password": "Pass123!"})
    return resp.json()["access_token"]


@pytest.mark.asyncio
async def test_voice_transcribe_returns_text():
    """AC-6: POST /voice/transcribe forwards to Whisper and returns transcript."""
    mock_transcription = MagicMock()
    mock_transcription.text = "Hello, this is a test transcription"

    with patch("app.api.routes.voice.transcribe_audio", new_callable=AsyncMock) as mock_fn:
        mock_fn.return_value = mock_transcription.text

        async with await get_client() as client:
            token = await register_and_login(client, "voice1@example.com")
            audio_bytes = b"fake-audio-data"
            response = await client.post(
                "/voice/transcribe",
                content=audio_bytes,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "audio/webm",
                },
            )

    assert response.status_code == 200
    data = response.json()
    assert "text" in data
    assert data["text"] == "Hello, this is a test transcription"


@pytest.mark.asyncio
async def test_voice_transcribe_requires_auth():
    """Security: transcribe endpoint requires authentication."""
    async with await get_client() as client:
        response = await client.post(
            "/voice/transcribe",
            content=b"audio",
            headers={"Content-Type": "audio/webm"},
        )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_share_memo_returns_memo_data():
    """AC-7: GET /memos/{id}/share returns memo data (200 + memo payload)."""
    async with await get_client() as client:
        token = await register_and_login(client, "share1@example.com")
        create_resp = await client.post(
            "/memos",
            json={"title": "Shared Memo", "content": "Share content"},
            headers={"Authorization": f"Bearer {token}"},
        )
        memo_id = create_resp.json()["id"]

        response = await client.get(
            f"/memos/{memo_id}/share",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 200
    data = response.json()
    assert data["id"] == memo_id
    assert data["title"] == "Shared Memo"
    assert data["content"] == "Share content"
