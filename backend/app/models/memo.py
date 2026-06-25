"""SQLAlchemy Memo model (REQ-B-008).

Schema matches spec:
    memos(id UUID, user_id UUID, title TEXT, content TEXT, voice_url TEXT,
          markdown_enabled BOOL, created_at, updated_at, version INT, deleted_at)
"""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import Text, Boolean, Integer, DateTime, ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Memo(Base):
    __tablename__ = "memos"

    id: Mapped[str] = mapped_column(
        Text, primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        Text, ForeignKey("users.id"), nullable=False
    )
    title: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    content: Mapped[str] = mapped_column(Text, nullable=False, default="")
    voice_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    markdown_enabled: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    __table_args__ = (
        Index("idx_memos_user_updated", "user_id", "updated_at"),
    )
