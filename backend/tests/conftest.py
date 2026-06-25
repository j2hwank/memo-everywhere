"""
Shared pytest fixtures for all backend tests.
Uses SQLite in-memory DB via DATABASE_URL env override.
"""
import os
import pytest
import pytest_asyncio

# Override DB to SQLite for tests BEFORE any app import
os.environ.setdefault(
    "DATABASE_URL", "sqlite+aiosqlite:///./test.db"
)
os.environ.setdefault("JWT_SECRET", "test-secret-key-for-testing-only")
os.environ.setdefault("OPENAI_API_KEY", "sk-test-fake-key")


@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"


@pytest_asyncio.fixture(autouse=True)
async def setup_test_db():
    """Create and teardown tables for each test."""
    from app.core.db import engine, Base
    from app.models import memo, user  # noqa: F401 — import to register models

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
