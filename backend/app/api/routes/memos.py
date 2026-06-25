"""
Memo CRUD endpoints (REQ-B-003, REQ-B-004, REQ-B-005, REQ-B-007):
  POST   /memos
  GET    /memos         (?since= for incremental sync)
  GET    /memos/{id}
  PUT    /memos/{id}    (LWW conflict resolution)
  DELETE /memos/{id}    (soft delete)
  GET    /memos/{id}/share

# @MX:ANCHOR: [AUTO] upsert_memo — LWW sync correctness invariant.
# @MX:REASON: Both mobile and desktop clients depend on this conflict resolution;
#             wrong behaviour silently loses user data.
"""
from datetime import datetime, timezone
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.db import get_db
from app.models.memo import Memo
from app.models.user import User
from app.schemas.memo_schema import MemoCreate, MemoUpdate, MemoResponse
from app.api.routes.deps import get_current_user

router = APIRouter()


@router.post("", response_model=MemoResponse, status_code=201)
async def create_memo(
    body: MemoCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    memo = Memo(
        user_id=current_user.id,
        title=body.title,
        content=body.content,
        voice_url=body.voice_url,
        markdown_enabled=body.markdown_enabled,
    )
    db.add(memo)
    await db.flush()
    await db.refresh(memo)
    return MemoResponse.model_validate(memo)


@router.get("", response_model=List[MemoResponse])
async def list_memos(
    since: Optional[datetime] = Query(None, description="Return memos updated after this timestamp (ISO 8601)"),
    include_deleted: bool = Query(False, description="Include soft-deleted memos (for sync propagation)"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """AC-3 + AC-5: Return memos for the current user. Supports ?since= for incremental sync."""
    q = select(Memo).where(Memo.user_id == current_user.id)

    if not include_deleted:
        q = q.where(Memo.deleted_at.is_(None))

    if since:
        # Normalize since to UTC naive for SQLite compatibility
        since_utc = since
        if since_utc.tzinfo is not None:
            since_utc = since_utc.replace(tzinfo=None)
        q = q.where(Memo.updated_at > since_utc)

    q = q.order_by(Memo.updated_at.desc())
    result = await db.execute(q)
    memos = result.scalars().all()
    return [MemoResponse.model_validate(m) for m in memos]


@router.get("/{memo_id}/share", response_model=MemoResponse)
async def share_memo(
    memo_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """AC-7: Returns memo data (signed URL is a future capability)."""
    memo = await _get_owned_memo(memo_id, current_user.id, db)
    return MemoResponse.model_validate(memo)


@router.get("/{memo_id}", response_model=MemoResponse)
async def get_memo(
    memo_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """AC-3: Retrieve a single memo owned by the current user."""
    memo = await _get_owned_memo(memo_id, current_user.id, db)
    return MemoResponse.model_validate(memo)


@router.put("/{memo_id}", response_model=MemoResponse)
async def upsert_memo(
    memo_id: str,
    body: MemoUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # @MX:ANCHOR: [AUTO] upsert_memo — create-or-update by client-supplied id.
    # @MX:REASON: All sync clients share this invariant: the client id is the
    #             canonical id across devices. Wrong id handling silently duplicates
    #             memos on every sync. Cross-user isolation is also enforced here.
    """AC-3 + AC-4 + upsert: Create-or-update memo identified by client-supplied id.

    Upsert semantics (REQ-B-004, REQ-B-005 upsert variant):
    - If memo_id does NOT exist for current_user → CREATE with that exact id.
    - If memo_id exists for current_user → apply LWW update logic (unchanged).
    - If memo_id exists for a DIFFERENT user → 404 (row-level isolation, no leak).

    LWW rule on update:
    - server.updated_at >= client.updated_at → server wins, return existing
    - client.updated_at > server.updated_at → client wins, overwrite
    """
    now = datetime.now(timezone.utc)

    # Check if memo exists (any owner) to enforce cross-user isolation.
    existing_result = await db.execute(select(Memo).where(Memo.id == memo_id))
    existing = existing_result.scalar_one_or_none()

    if existing is not None and existing.user_id != current_user.id:
        # Memo exists but belongs to another user → 404 (do not reveal existence).
        raise HTTPException(status_code=404, detail="Memo not found")

    if existing is None:
        # --- CREATE path: memo with this id does not exist yet ---
        client_updated_at = body.updated_at
        if client_updated_at and client_updated_at.tzinfo is None:
            client_updated_at = client_updated_at.replace(tzinfo=timezone.utc)

        memo = Memo(
            id=memo_id,
            user_id=current_user.id,
            title=body.title,
            content=body.content if body.content is not None else "",
            voice_url=body.voice_url,
            markdown_enabled=body.markdown_enabled if body.markdown_enabled is not None else False,
            created_at=now,
            updated_at=client_updated_at if client_updated_at else now,
            version=1,
        )
        db.add(memo)
        await db.flush()
        await db.refresh(memo)
        return MemoResponse.model_validate(memo)

    # --- UPDATE path: memo exists and is owned by current_user ---
    memo = existing

    client_updated_at = body.updated_at
    if client_updated_at and client_updated_at.tzinfo is None:
        client_updated_at = client_updated_at.replace(tzinfo=timezone.utc)

    # Normalize server timestamp: SQLite stores naive UTC; make aware for comparison.
    server_updated_at = memo.updated_at
    if server_updated_at.tzinfo is None:
        server_updated_at = server_updated_at.replace(tzinfo=timezone.utc)

    # LWW: server wins if it is equal or newer
    if client_updated_at and server_updated_at >= client_updated_at:
        return MemoResponse.model_validate(memo)

    if body.title is not None:
        memo.title = body.title
    if body.content is not None:
        memo.content = body.content
    if body.voice_url is not None:
        memo.voice_url = body.voice_url
    if body.markdown_enabled is not None:
        memo.markdown_enabled = body.markdown_enabled
    memo.updated_at = now
    memo.version += 1

    await db.flush()
    await db.refresh(memo)
    return MemoResponse.model_validate(memo)


@router.delete("/{memo_id}", response_model=MemoResponse)
async def delete_memo(
    memo_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """AC-3: Soft-delete by setting deleted_at. Row is preserved for sync propagation."""
    memo = await _get_owned_memo(memo_id, current_user.id, db)
    now = datetime.now(timezone.utc)
    memo.deleted_at = now
    memo.updated_at = now
    memo.version += 1
    await db.flush()
    await db.refresh(memo)
    return MemoResponse.model_validate(memo)


async def _get_owned_memo(memo_id: str, user_id: str, db: AsyncSession) -> Memo:
    """Helper: fetch a memo by id and user_id, raise 404 if not found (row-level isolation)."""
    result = await db.execute(
        select(Memo).where(Memo.id == memo_id, Memo.user_id == user_id)
    )
    memo = result.scalar_one_or_none()
    if not memo:
        raise HTTPException(status_code=404, detail="Memo not found")
    return memo
