"""
RED tests for PUT /memos/{id} upsert (client-generated uuid) and sync pull.

Covers:
- PUT creates when id does not exist (client id is preserved)
- PUT updates when id exists (LWW semantics unchanged)
- PUT idempotency: two identical PUTs produce exactly one row
- Cross-user isolation: PUT on another user's memo → 404
- GET ?since=&include_deleted=true returns soft-deleted rows with deleted_at set

REQ: REQ-B-004, REQ-B-005 (upsert variant)
"""
import uuid
import pytest
from datetime import datetime, timezone, timedelta
from httpx import AsyncClient, ASGITransport


async def get_client():
    from app.main import app
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def register_and_login(client: AsyncClient, email: str, password: str = "Pass123!") -> str:
    await client.post("/auth/register", json={"email": email, "password": password})
    resp = await client.post("/auth/login", json={"email": email, "password": password})
    return resp.json()["access_token"]


@pytest.mark.asyncio
async def test_put_creates_memo_with_client_id():
    """PUT /memos/{uuid} creates a new memo when the id does not exist.

    The server MUST use the client-supplied id as the canonical id,
    not generate a new one.  This enables cross-device id consistency.
    """
    client_id = str(uuid.uuid4())
    async with await get_client() as client:
        token = await register_and_login(client, "upsert_create@example.com")

        resp = await client.put(
            f"/memos/{client_id}",
            json={
                "title": "Client-side memo",
                "content": "Created by client",
                "updated_at": datetime.now(timezone.utc).isoformat(),
            },
            headers={"Authorization": f"Bearer {token}"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == client_id, "Server must preserve the client-supplied id"
    assert data["title"] == "Client-side memo"
    assert data["content"] == "Created by client"
    assert "created_at" in data
    assert "updated_at" in data
    assert "deleted_at" in data  # MemoResponse must include deleted_at


@pytest.mark.asyncio
async def test_put_updates_existing_memo_lww_client_wins():
    """PUT on an existing memo applies LWW: client with future timestamp wins."""
    async with await get_client() as client:
        token = await register_and_login(client, "upsert_lww_client@example.com")

        # First: create via POST so id is server-generated (backward compat)
        create_resp = await client.post(
            "/memos",
            json={"content": "original content"},
            headers={"Authorization": f"Bearer {token}"},
        )
        memo_id = create_resp.json()["id"]

        future_ts = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
        resp = await client.put(
            f"/memos/{memo_id}",
            json={"content": "updated by client", "updated_at": future_ts},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert resp.status_code == 200
    assert resp.json()["content"] == "updated by client"


@pytest.mark.asyncio
async def test_put_idempotency_same_id_creates_one_row():
    """Two PUT requests with the same client id produce exactly one memo row."""
    client_id = str(uuid.uuid4())
    ts = datetime.now(timezone.utc).isoformat()

    async with await get_client() as client:
        token = await register_and_login(client, "upsert_idem@example.com")

        payload = {
            "title": "Idempotent memo",
            "content": "same content",
            "updated_at": ts,
        }
        # First upsert
        r1 = await client.put(
            f"/memos/{client_id}",
            json=payload,
            headers={"Authorization": f"Bearer {token}"},
        )
        # Second upsert with identical payload (server timestamp >= client → server wins,
        # but the row must still exist and be the same row)
        r2 = await client.put(
            f"/memos/{client_id}",
            json=payload,
            headers={"Authorization": f"Bearer {token}"},
        )

        # Verify only one row in the list
        list_resp = await client.get(
            "/memos",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert r1.status_code == 200
    assert r2.status_code == 200
    assert r1.json()["id"] == client_id
    assert r2.json()["id"] == client_id
    # Exactly one memo in list
    assert len(list_resp.json()) == 1


@pytest.mark.asyncio
async def test_put_cross_user_returns_404():
    """PUT on another user's memo id must return 404 (row-level isolation).

    The attacker must NOT be able to read the victim's data or overwrite it.
    """
    victim_id = str(uuid.uuid4())
    async with await get_client() as client:
        token_victim = await register_and_login(client, "upsert_victim@example.com")
        token_attacker = await register_and_login(client, "upsert_attacker@example.com")

        # Victim creates a memo with a known client id
        await client.put(
            f"/memos/{victim_id}",
            json={"content": "victim secret", "updated_at": datetime.now(timezone.utc).isoformat()},
            headers={"Authorization": f"Bearer {token_victim}"},
        )

        # Attacker tries to update victim's memo
        resp = await client.put(
            f"/memos/{victim_id}",
            json={"content": "attacker overwrite", "updated_at": (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()},
            headers={"Authorization": f"Bearer {token_attacker}"},
        )

    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_get_since_include_deleted_returns_deleted_rows():
    """GET /memos?since=T&include_deleted=true returns soft-deleted rows with deleted_at.

    Clients need this to propagate deletions during pull sync.
    """
    async with await get_client() as client:
        token = await register_and_login(client, "upsert_del_since@example.com")

        create_resp = await client.post(
            "/memos",
            json={"content": "will be soft-deleted"},
            headers={"Authorization": f"Bearer {token}"},
        )
        memo_id = create_resp.json()["id"]

        cutoff = datetime.now(timezone.utc)
        import asyncio
        await asyncio.sleep(0.01)

        # Soft-delete
        await client.delete(
            f"/memos/{memo_id}",
            headers={"Authorization": f"Bearer {token}"},
        )

        since_param = cutoff.strftime("%Y-%m-%dT%H:%M:%S.%f")
        resp = await client.get(
            "/memos",
            params={"since": since_param, "include_deleted": "true"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert resp.status_code == 200
    items = resp.json()
    matched = [m for m in items if m["id"] == memo_id]
    assert len(matched) == 1, "Soft-deleted memo must appear in ?since=&include_deleted=true"
    assert matched[0]["deleted_at"] is not None, "deleted_at must be populated in MemoResponse"
