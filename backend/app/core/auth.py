"""
JWT token creation/verification and password hashing (REQ-B-002).

# @MX:ANCHOR: [AUTO] create_tokens — all protected endpoints depend on this auth contract.
# @MX:REASON: access_token and refresh_token fan_in >= 5 (all auth + every memo endpoint).

# @MX:ANCHOR: [AUTO] hash_password / verify_password — security invariant: plaintext must never be stored.
# @MX:REASON: bcrypt hash path is the single point preventing credential exposure.
"""
import time
from datetime import timedelta
from uuid import UUID

from jose import JWTError, jwt
import bcrypt as _bcrypt

from app.core.config import settings


def hash_password(plain: str) -> str:
    # @MX:ANCHOR: [AUTO] Security invariant — always hash; never store plaintext.
    # @MX:REASON: Plaintext password storage is prohibited by REQ-B-002 security req.
    salt = _bcrypt.gensalt()
    return _bcrypt.hashpw(plain.encode(), salt).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return _bcrypt.checkpw(plain.encode(), hashed.encode())


def create_tokens(user_id: str) -> dict:
    """Issue access (24 h) and refresh (30 d) tokens for the given user ID.

    # @MX:ANCHOR: [AUTO] Central token factory — all login/refresh flows depend here.
    # @MX:REASON: Token structure (type claim, expiry) is an invariant contract.
    """
    now = time.time()
    access_exp = now + timedelta(hours=settings.access_token_expire_hours).total_seconds()
    refresh_exp = now + timedelta(days=settings.refresh_token_expire_days).total_seconds()

    access_token = jwt.encode(
        {"sub": str(user_id), "exp": access_exp, "type": "access"},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )
    refresh_token = jwt.encode(
        {"sub": str(user_id), "exp": refresh_exp, "type": "refresh"},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }


def decode_token(token: str, expected_type: str) -> dict:
    """Decode and validate a JWT, raising ValueError on any failure."""
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except JWTError as exc:
        raise ValueError(f"Invalid token: {exc}") from exc

    if payload.get("type") != expected_type:
        raise ValueError(f"Expected token type '{expected_type}', got '{payload.get('type')}'")

    return payload
