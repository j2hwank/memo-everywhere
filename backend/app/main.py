"""
FastAPI application entry point.

Registers routers for auth, memos, and voice endpoints.
"""
from fastapi import FastAPI

from app.core.config import settings

app = FastAPI(title="Memo Everywhere API", version=settings.app_version)


@app.get("/health")
async def health_check():
    """AC-1: Liveness probe endpoint."""
    return {"status": "ok", "version": settings.app_version}


from app.api.routes import auth as auth_router
from app.api.routes import memos as memos_router
from app.api.routes import voice as voice_router

app.include_router(auth_router.router, prefix="/auth", tags=["auth"])
app.include_router(memos_router.router, prefix="/memos", tags=["memos"])
app.include_router(voice_router.router, prefix="/voice", tags=["voice"])
