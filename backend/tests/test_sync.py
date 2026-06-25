"""
Phase 4 RED: LWW conflict resolution and incremental sync.

Tests (AC-4, AC-5):
- AC-4: Two clients edit same memo → later updated_at wins
- AC-5: GET /memos?since=T returns only memos updated after T
- Deleted memos also appear in ?since= result (for sync propagation)
"""
import pytest
from datetime import datetime, timezone, timedelta
from httpx import AsyncClient, ASGITransport


async def get_client():
    from app.main import app
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def register_and_login(client: AsyncClient, email: str):
    await client.post("/auth/register", json={"email": email, "password": "Pass123!"})
    resp = await client.post("/auth/login", json={"email": email, "password": "Pass123!"})
    return resp.json()["access_token"]


@pytest.mark.asyncio
async def test_lww_client_newer_wins():
    """AC-4: If client's updated_at is later than server's, client change wins."""
    async with await get_client() as client:
        token = await register_and_login(client, "lww1@example.com")

        create_resp = await client.post(
            "/memos",
            json={"content": "original"},
            headers={"Authorization": f"Bearer {token}"},
        )
        memo_id = create_resp.json()["id"]

        # Client sends an update with future timestamp → should win
        future_ts = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
        update_resp = await client.put(
            f"/memos/{memo_id}",
            json={"content": "client update", "updated_at": future_ts},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert update_resp.status_code == 200
    assert update_resp.json()["content"] == "client update"


@pytest.mark.asyncio
async def test_lww_server_newer_wins():
    """AC-4: If server's updated_at >= client's, server wins (client change ignored)."""
    async with await get_client() as client:
        token = await register_and_login(client, "lww2@example.com")

        create_resp = await client.post(
            "/memos",
            json={"content": "server version"},
            headers={"Authorization": f"Bearer {token}"},
        )
        memo_id = create_resp.json()["id"]

        # Client sends stale timestamp → server should win
        past_ts = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
        update_resp = await client.put(
            f"/memos/{memo_id}",
            json={"content": "stale client update", "updated_at": past_ts},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert update_resp.status_code == 200
    # Server version should be preserved
    assert update_resp.json()["content"] == "server version"


@pytest.mark.asyncio
async def test_since_returns_only_newer_memos():
    """AC-5: GET /memos?since=T returns only memos updated after T."""
    async with await get_client() as client:
        token = await register_and_login(client, "since1@example.com")

        # Create memo before cutoff
        await client.post(
            "/memos",
            json={"content": "before cutoff"},
            headers={"Authorization": f"Bearer {token}"},
        )

        cutoff = datetime.now(timezone.utc)

        # Small sleep to ensure different timestamp
        import asyncio
        await asyncio.sleep(0.01)

        # Create memo after cutoff
        await client.post(
            "/memos",
            json={"content": "after cutoff"},
            headers={"Authorization": f"Bearer {token}"},
        )

        # Use UTC format without +00:00 to avoid URL encoding issues
        since_param = cutoff.strftime("%Y-%m-%dT%H:%M:%S.%f")
        response = await client.get(
            "/memos",
            params={"since": since_param},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 200
    items = response.json()
    assert len(items) == 1
    assert items[0]["content"] == "after cutoff"


@pytest.mark.asyncio
async def test_deleted_memo_appears_in_since_results():
    """Deleted memos must appear in ?since= to propagate deletion to clients."""
    async with await get_client() as client:
        token = await register_and_login(client, "since2@example.com")

        create_resp = await client.post(
            "/memos",
            json={"content": "will be deleted"},
            headers={"Authorization": f"Bearer {token}"},
        )
        memo_id = create_resp.json()["id"]

        cutoff = datetime.now(timezone.utc)
        import asyncio
        await asyncio.sleep(0.01)

        # Soft-delete the memo
        await client.delete(
            f"/memos/{memo_id}",
            headers={"Authorization": f"Bearer {token}"},
        )

        # Must appear in since results so clients know to delete locally
        since_param = cutoff.strftime("%Y-%m-%dT%H:%M:%S.%f")
        response = await client.get(
            "/memos",
            params={"since": since_param, "include_deleted": "true"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 200
    # The deleted memo should be in the results
    ids = [m["id"] for m in response.json()]
    assert memo_id in ids
