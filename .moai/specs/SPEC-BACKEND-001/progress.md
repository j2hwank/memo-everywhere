# SPEC-BACKEND-001 Progress

## Status: COMPLETE

## Acceptance Criteria Completion

| # | Condition | Status | Test |
|---|-----------|--------|------|
| AC-1 | FastAPI starts + connects to DB | PASS | test_health.py |
| AC-2 | Login returns access(24h)/refresh(30d) JWT | PASS | test_auth.py::test_login_returns_tokens |
| AC-3 | 5 CRUD endpoints work, own memos only | PASS | test_memos.py (7 tests) |
| AC-4 | LWW — later updated_at wins | PASS | test_sync.py::test_lww_* |
| AC-5 | GET /memos?since=T returns only after T | PASS | test_sync.py::test_since_* |
| AC-6 | POST /voice/transcribe → Whisper → text | PASS | test_voice.py::test_voice_transcribe_returns_text |
| AC-7 | GET /memos/{id}/share returns memo data | PASS | test_voice.py::test_share_memo_returns_memo_data |
| AC-8 | PostgreSQL schema with specified columns | PASS | alembic/versions/001_initial_schema.py |
| AC-9 | Foreground + save triggers SyncService.sync() | PASS | sync_service_test.dart |
| AC-10 | Offline ops queued, replayed on reconnect | PASS | sync_service_test.dart |

## Test Results

### Backend (Python / pytest)
- 21 tests, 21 passed, 0 failed
- Phases: health(2), auth(5), memos(7), sync(4), voice(3)

### Flutter (Dart / flutter test)
- 61 tests, 61 passed, 0 failed
- New tests: remote datasources(6), sync_memos(3), sync_service(5)

## Phases Completed

- Phase 1 — Backend scaffold + DB: FastAPI, SQLAlchemy, models, health check
- Phase 2 — Authentication: JWT create/verify, bcrypt passwords, register/login/refresh
- Phase 3 — Memo CRUD + isolation: 5 endpoints, soft delete, user-level row isolation
- Phase 4 — Sync (LWW + incremental): PUT with LWW, GET /memos?since=
- Phase 5 — Whisper proxy + share: POST /voice/transcribe (mocked), GET /memos/{id}/share
- Phase 6 — Flutter client: remote datasources, SyncMemos UseCase, SyncService

## Files Created

### Backend
- backend/app/main.py
- backend/app/core/config.py, db.py, auth.py
- backend/app/models/user.py, memo.py
- backend/app/schemas/auth_schema.py, memo_schema.py
- backend/app/api/routes/auth.py, memos.py, voice.py, deps.py
- backend/alembic/env.py, versions/001_initial_schema.py
- backend/tests/test_health.py, test_auth.py, test_memos.py, test_sync.py, test_voice.py
- backend/requirements.txt, pytest.ini, alembic.ini, .env.example

### Flutter
- lib/data/datasources/remote/memo_remote_datasource.dart
- lib/data/datasources/remote/auth_remote_datasource.dart
- lib/domain/usecases/sync_memos.dart
- lib/core/services/sync_service.dart
- test/unit/data/remote/memo_remote_datasource_test.dart
- test/unit/data/remote/auth_remote_datasource_test.dart
- test/unit/domain/sync_memos_test.dart
- test/unit/domain/sync_service_test.dart

## Completion Date: 2026-06-25
