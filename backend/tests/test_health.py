"""
Phase 1 RED: FastAPI app starts and /health returns 200.
This test fails until main.py and db.py are implemented.
"""
import pytest
from httpx import AsyncClient, ASGITransport


@pytest.mark.asyncio
async def test_health_returns_200():
    """AC-1: FastAPI server starts and health endpoint is reachable."""
    from app.main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get("/health")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"


@pytest.mark.asyncio
async def test_health_includes_version():
    """Health endpoint returns a version field."""
    from app.main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get("/health")

    assert "version" in response.json()
