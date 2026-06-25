"""
Phase 2 RED: Authentication endpoints.

Tests:
- POST /auth/register → 201 with user info
- POST /auth/login → access token (24h) + refresh token (30d)
- POST /auth/login with wrong password → 401
- POST /auth/refresh → new access token
- Duplicate email registration → 400
"""
import pytest
from httpx import AsyncClient, ASGITransport
from jose import jwt as jose_jwt

from app.core.config import settings


async def get_client():
    from app.main import app
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


@pytest.mark.asyncio
async def test_register_returns_201():
    """AC-2 prerequisite: Register new user returns 201."""
    async with await get_client() as client:
        response = await client.post(
            "/auth/register",
            json={"email": "test@example.com", "password": "Pass123!"},
        )
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "test@example.com"
    assert "id" in data
    assert "hashed_password" not in data  # password must not be exposed


@pytest.mark.asyncio
async def test_login_returns_tokens():
    """AC-2: Login returns access(24h) and refresh(30d) JWT tokens."""
    async with await get_client() as client:
        await client.post(
            "/auth/register",
            json={"email": "login@example.com", "password": "Pass123!"},
        )
        response = await client.post(
            "/auth/login",
            json={"email": "login@example.com", "password": "Pass123!"},
        )

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"

    # Verify access token expiry is ~24 hours
    access_payload = jose_jwt.decode(
        data["access_token"],
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
    )
    assert access_payload["type"] == "access"
    import time
    exp_hours = (access_payload["exp"] - time.time()) / 3600
    assert 23 < exp_hours <= 24

    # Verify refresh token expiry is ~30 days
    refresh_payload = jose_jwt.decode(
        data["refresh_token"],
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
    )
    assert refresh_payload["type"] == "refresh"
    exp_days = (refresh_payload["exp"] - time.time()) / 86400
    assert 29 < exp_days <= 30


@pytest.mark.asyncio
async def test_login_wrong_password_returns_401():
    """Security: wrong password must return 401."""
    async with await get_client() as client:
        await client.post(
            "/auth/register",
            json={"email": "badpass@example.com", "password": "CorrectP1!"},
        )
        response = await client.post(
            "/auth/login",
            json={"email": "badpass@example.com", "password": "WrongP1!"},
        )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_register_duplicate_email_returns_400():
    """Integrity: duplicate email must return 400."""
    async with await get_client() as client:
        await client.post(
            "/auth/register",
            json={"email": "dup@example.com", "password": "Pass123!"},
        )
        response = await client.post(
            "/auth/register",
            json={"email": "dup@example.com", "password": "OtherPass123!"},
        )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_refresh_token_returns_new_access_token():
    """AC-2: /auth/refresh issues a new access token from a valid refresh token."""
    async with await get_client() as client:
        await client.post(
            "/auth/register",
            json={"email": "refresh@example.com", "password": "Pass123!"},
        )
        login_resp = await client.post(
            "/auth/login",
            json={"email": "refresh@example.com", "password": "Pass123!"},
        )
        refresh_token = login_resp.json()["refresh_token"]

        response = await client.post(
            "/auth/refresh",
            json={"refresh_token": refresh_token},
        )

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
