"""Pydantic schemas for memo CRUD and sync (REQ-B-003, REQ-B-005)."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class MemoCreate(BaseModel):
    title: Optional[str] = None
    content: str = ""
    voice_url: Optional[str] = None
    markdown_enabled: bool = False


class MemoUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    voice_url: Optional[str] = None
    markdown_enabled: Optional[bool] = None
    # Client's updated_at for LWW comparison (REQ-B-004)
    updated_at: Optional[datetime] = None


class MemoResponse(BaseModel):
    id: str
    user_id: str
    title: Optional[str]
    content: str
    voice_url: Optional[str]
    markdown_enabled: bool
    created_at: datetime
    updated_at: datetime
    version: int
    deleted_at: Optional[datetime]

    model_config = {"from_attributes": True}
