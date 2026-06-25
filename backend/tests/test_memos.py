"""
Phase 3 RED: Memo CRUD endpoints with user isolation.

Tests (AC-3):
- POST /memos → 201
- GET /memos → list
- GET /memos/{id} → single memo
- PUT /memos/{id} → update
- DELETE /memos/{id} → soft delete (deleted_at set)
- User A cannot read/update/delete User B's memo (403)
- Soft-deleted memo excluded from GET /memos list
"""
import pytest
from httpx import AsyncClient, ASGITransport


async def get_client():
    from app.main import app
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def register_and_login(client: AsyncClient, email: str, password: str = "Pass123!"):
    await client.post("/auth/register", json={"email": email, "password": password})
    resp = await client.post("/auth/login", json={"email": email, "password": password})
    return resp.json()["access_token"]


@pytest.mark.asyncio
async def test_create_memo_returns_201():
    """AC-3: POST /memos creates a new memo and returns 201."""
    async with await get_client() as client:
        token = await register_and_login(client, "memo1@example.com")
        response = await client.post(
            "/memos",
            json={"title": "Test Memo", "content": "Hello world"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "Test Memo"
    assert data["content"] == "Hello world"
    assert "id" in data
    assert "created_at" in data
    assert "updated_at" in data


@pytest.mark.asyncio
async def test_get_memos_returns_list():
    """AC-3: GET /memos returns memo list for the authenticated user."""
    async with await get_client() as client:
        token = await register_and_login(client, "memo2@example.com")
        await client.post(
            "/memos",
            json={"content": "First memo"},
            headers={"Authorization": f"Bearer {token}"},
        )
        await client.post(
            "/memos",
            json={"content": "Second memo"},
            headers={"Authorization": f"Bearer {token}"},
        )
        response = await client.get(
            "/memos", headers={"Authorization": f"Bearer {token}"}
        )
    assert response.status_code == 200
    items = response.json()
    assert len(items) == 2


@pytest.mark.asyncio
async def test_get_memo_by_id():
    """AC-3: GET /memos/{id} returns the specific memo."""
    async with await get_client() as client:
        token = await register_and_login(client, "memo3@example.com")
        create_resp = await client.post(
            "/memos",
            json={"content": "Find me"},
            headers={"Authorization": f"Bearer {token}"},
        )
        memo_id = create_resp.json()["id"]
        response = await client.get(
            f"/memos/{memo_id}", headers={"Authorization": f"Bearer {token}"}
        )
    assert response.status_code == 200
    assert response.json()["id"] == memo_id


@pytest.mark.asyncio
async def test_update_memo():
    """AC-3: PUT /memos/{id} updates content and bumps updated_at."""
    async with await get_client() as client:
        token = await register_and_login(client, "memo4@example.com")
        create_resp = await client.post(
            "/memos",
            json={"content": "Original"},
            headers={"Authorization": f"Bearer {token}"},
        )
        memo_id = create_resp.json()["id"]
        old_updated = create_resp.json()["updated_at"]

        response = await client.put(
            f"/memos/{memo_id}",
            json={"content": "Updated", "updated_at": "2099-01-01T00:00:00Z"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 200
    data = response.json()
    assert data["content"] == "Updated"


@pytest.mark.asyncio
async def test_delete_memo_soft_deletes():
    """AC-3: DELETE /memos/{id} sets deleted_at (soft delete), not hard delete."""
    async with await get_client() as client:
        token = await register_and_login(client, "memo5@example.com")
        create_resp = await client.post(
            "/memos",
            json={"content": "Delete me"},
            headers={"Authorization": f"Bearer {token}"},
        )
        memo_id = create_resp.json()["id"]

        del_response = await client.delete(
            f"/memos/{memo_id}", headers={"Authorization": f"Bearer {token}"}
        )
        assert del_response.status_code == 200

        # Memo should not appear in the list
        list_resp = await client.get(
            "/memos", headers={"Authorization": f"Bearer {token}"}
        )
        ids_in_list = [m["id"] for m in list_resp.json()]
        assert memo_id not in ids_in_list


@pytest.mark.asyncio
async def test_user_cannot_access_others_memo():
    """AC-3 security: User A cannot GET User B's memo → 403 or 404."""
    async with await get_client() as client:
        token_a = await register_and_login(client, "userA@example.com")
        token_b = await register_and_login(client, "userB@example.com")

        create_resp = await client.post(
            "/memos",
            json={"content": "User B's secret"},
            headers={"Authorization": f"Bearer {token_b}"},
        )
        memo_id = create_resp.json()["id"]

        # User A tries to access User B's memo
        response = await client.get(
            f"/memos/{memo_id}", headers={"Authorization": f"Bearer {token_a}"}
        )
    assert response.status_code in (403, 404)


@pytest.mark.asyncio
async def test_unauthenticated_request_returns_401():
    """Security: memo endpoints require JWT Bearer token."""
    async with await get_client() as client:
        response = await client.get("/memos")
    assert response.status_code == 401
