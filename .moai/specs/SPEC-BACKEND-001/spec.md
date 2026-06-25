---
spec_id: SPEC-BACKEND-001
title: "FastAPI 백엔드 + 크로스디바이스 동기화"
status: draft
version: 1.0.0
created: 2026-06-25
updated: 2026-06-25
author: manager-spec
priority: high
methodology: tdd
dependencies: [SPEC-MEMO-001]
---

# SPEC-BACKEND-001: FastAPI 백엔드 + 크로스디바이스 동기화

## HISTORY

- v1.0.0 — 2026-06-25 — initial draft

## 메타데이터
- **상태**: draft
- **버전**: 1.0.0
- **생성일**: 2026-06-25
- **의존성**: SPEC-MEMO-001 (동기화 대상 `Memo` 엔티티/로컬 저장소 재사용)

## 개요

자체 운영하는 **FastAPI + PostgreSQL 백엔드 서버**와 이를 통한 **크로스디바이스 동기화**를 정의한다. 동일 사용자의 메모가 Android 폰에서 작성되어 Mac 브라우저/앱에서 읽히는 등 여러 디바이스에서 접근 가능하도록 한다. JWT 기반 인증, 메모 CRUD REST API, Last-Write-Wins(LWW) 동기화, 증분 동기화, 오프라인 큐잉, 그리고 음성 메모를 위한 Whisper 프록시 엔드포인트를 포함한다. Supabase/Firebase가 아닌 자체 서버이다.

## 배경 및 동기

`product.md`의 핵심 기능 5번(클라우드 동기화, `#feature/sync`)과 6번(크로스플랫폼 지원), 사용 사례 3(멀티디바이스 메모 접근)을 충족한다. 현재 앱은 로컬 Hive 저장소만 사용하여 디바이스 간 메모 공유가 불가능하다. 이 백엔드는 개인의 메모를 여러 디바이스에서 일관되게 접근하기 위한 인프라이며, **소셜 공유가 아닌 개인 크로스디바이스 접근**이 목표이다. `product.md` 성공 지표(동기화 시간 < 2초, 오프라인 동작 100%)를 만족해야 한다.

본 SPEC은 SPEC-VOICE-001(클라우드 STT 폴백)과 SPEC-WEB-MARKDOWN-001(웹 플랫폼 저장소)의 의존 대상이며, 프로젝트에서 가장 큰 SPEC이다. 백엔드는 신규 최상위 `backend/` 디렉터리에 독립 FastAPI 프로젝트로 구성한다.

## 요구사항 (EARS 형식)

### 기능 요구사항

#### REQ-B-001: 서버 + 데이터 스토어
The system SHALL provide a FastAPI server with PostgreSQL as the persistent data store.

#### REQ-B-002: 인증 토큰 발급
WHEN a user registers or logs in, the system SHALL issue a JWT access token (24-hour expiry) and a refresh token (30-day expiry).

#### REQ-B-003: 메모 CRUD 엔드포인트
The system SHALL provide memo CRUD endpoints: `POST /memos`, `GET /memos`, `GET /memos/{id}`, `PUT /memos/{id}`, `DELETE /memos/{id}`.

#### REQ-B-004: Last-Write-Wins 충돌 해결
WHEN a Flutter client syncs, the system SHALL resolve conflicts using a Last-Write-Wins (LWW) strategy based on the `updated_at` timestamp.

#### REQ-B-005: 증분 동기화
The system SHALL support incremental sync: `GET /memos?since={timestamp}` SHALL return only memos updated after the given timestamp.

#### REQ-B-006: Whisper 음성 변환 프록시
WHEN a user uploads audio via `POST /voice/transcribe`, the system SHALL forward the audio to the OpenAI Whisper API and return the transcription text.

#### REQ-B-007: 공유 읽기 전용 URL
The system SHALL provide a `GET /memos/{id}/share` endpoint that returns a signed read-only URL (future capability; currently it returns the memo data only).

#### REQ-B-008: PostgreSQL 스키마
The system SHALL store data in PostgreSQL using the schema `memos(id UUID, user_id UUID, title TEXT, content TEXT, voice_url TEXT, markdown_enabled BOOL, created_at, updated_at, version INT, deleted_at)`.

#### REQ-B-009: 자동 동기화 트리거
WHEN the app comes to the foreground OR a memo is saved AND network is available, the Flutter client SHALL automatically trigger a sync.

#### REQ-B-010: 오프라인 큐잉
WHILE the device is offline, the Flutter client SHALL continue to work locally and SHALL queue sync operations to be replayed when network connectivity returns.

### 비기능 요구사항

- **성능**: 단일 메모 동기화 왕복은 정상 네트워크에서 2초 이내(`product.md` 지표). 증분 동기화는 변경분만 전송한다.
- **보안**: 비밀번호는 bcrypt 등으로 해시 저장(평문 금지). 모든 메모 엔드포인트는 JWT 인증 필수. 사용자는 본인 `user_id`의 메모만 접근 가능(행 수준 격리). OWASP 입력 검증 준수.
- **자격증명 관리**: OpenAI API 키 등 시크릿은 환경변수로 주입(코드/저장소 커밋 금지).
- **데이터 무결성**: 삭제는 소프트 삭제(`deleted_at`)로 처리하여 동기화 시 삭제 전파가 가능하도록 한다. `version`은 LWW 보조 및 디버깅용으로 증가한다.
- **클라이언트 토큰 저장**: Flutter는 JWT를 `flutter_secure_storage`에 안전 보관한다.

## 구현 범위

### 포함 (In Scope)
- 신규 `backend/` FastAPI 프로젝트 (PostgreSQL)
- 회원가입/로그인 + JWT access(24h)/refresh(30d) 발급 및 갱신
- 메모 CRUD REST API (5개 엔드포인트)
- LWW 기반 충돌 해결 (`updated_at` 기준)
- 증분 동기화 `GET /memos?since=`
- 소프트 삭제 및 삭제 전파
- Whisper 프록시 `POST /voice/transcribe` (OpenAI 전달)
- `GET /memos/{id}/share` (현재는 메모 데이터 반환, 서명 URL은 향후)
- Flutter 측: 원격 데이터소스(메모/인증), 동기화 UseCase, `SyncService`(포그라운드/저장 트리거, 오프라인 큐)
- JWT 보안 저장(`flutter_secure_storage`)

### 제외 (Out of Scope)
- **협업/실시간 다중 사용자 편집** — `product.md` Non-Goal. 동기화는 개인 계정 단위이며 실시간 협업 편집은 제외한다.
- **소셜 공유/공개 게시** — 본 SPEC은 개인 크로스디바이스 접근이며, 타인과의 공유는 `GET /memos/{id}/share`의 향후 서명 URL로 한정한다(현재 구현 제외).
- **이미지/파일 첨부 스토리지** — `product.md` Non-Goal. 메모는 텍스트/음성 URL만 저장한다.
- **알림/푸시** — `product.md` Non-Goal. 동기화 완료 푸시/리마인더는 제외한다.
- **Supabase/Firebase 등 BaaS** — 자체 FastAPI 서버만 사용한다(BaaS 도입 제외).
- **태그/폴더 동기화 스키마** — 본 SPEC 스키마는 `memos` 테이블에 한정한다. 태그/폴더 동기화는 별도 SPEC으로 분리한다.
- **CRDT/벡터클록 고급 충돌 해결** — LWW만 구현한다.
- **배포 인프라(Docker/CI/CD)** — 서버 컨테이너화 및 배포 파이프라인은 별도 DevOps SPEC으로 분리한다.

## 인수 조건 (Acceptance Criteria)

| # | 조건 | 검증 방법 |
|---|------|---------|
| AC-1 | FastAPI 서버가 PostgreSQL에 연결되어 기동됨 | 통합 테스트: 헬스체크 + DB 마이그레이션 적용 후 연결 검증 |
| AC-2 | 로그인 시 access(24h)/refresh(30d) JWT 발급 | API 테스트: 토큰 디코드 후 `exp` 만료 시각 검증 |
| AC-3 | 5개 메모 CRUD 엔드포인트가 인증된 사용자에 대해 동작 | API 테스트: 각 엔드포인트 상태코드 + 본인 메모만 접근 검증 |
| AC-4 | 같은 메모를 두 디바이스가 수정 시 `updated_at` 최신이 승리 | 통합 테스트: 더 늦은 `updated_at` 페이로드가 최종 상태가 됨 |
| AC-5 | `GET /memos?since=T`가 T 이후 변경분만 반환 | API 테스트: 타임스탬프 경계로 결과 집합 검증 |
| AC-6 | `POST /voice/transcribe`가 오디오를 Whisper로 전달하고 텍스트 반환 | API 테스트: 모의 OpenAI 클라이언트 → `{text}` 응답 검증 |
| AC-7 | `GET /memos/{id}/share`가 메모 데이터를 반환 | API 테스트: 200 + 메모 페이로드 검증 |
| AC-8 | PostgreSQL `memos` 스키마가 명시된 컬럼/타입으로 생성됨 | 마이그레이션 테스트: 컬럼/타입/제약 검증 |
| AC-9 | 앱 포그라운드 진입 및 메모 저장 시(네트워크 가용) 자동 동기화 발생 | Flutter 단위 테스트: 라이프사이클/저장 이벤트 → `SyncService.sync()` 호출 |
| AC-10 | 오프라인 상태에서 작업이 큐에 쌓이고 복귀 시 재생됨 | Flutter 단위 테스트: 네트워크 false → 큐 적재, true 복귀 → 큐 플러시 |

## 기술 설계 (Technical Design)

### 백엔드 디렉터리 구조 (신규 `backend/`)

```
backend/
├── app/
│   ├── main.py                 # FastAPI 앱 진입점, 라우터 등록
│   ├── api/routes/
│   │   ├── auth.py             # /auth/register, /auth/login, /auth/refresh
│   │   ├── memos.py            # /memos CRUD + ?since= + /share
│   │   └── voice.py            # /voice/transcribe (Whisper 프록시)
│   ├── models/
│   │   ├── memo.py             # SQLAlchemy Memo 모델
│   │   └── user.py             # SQLAlchemy User 모델
│   ├── core/
│   │   ├── auth.py             # JWT 발급/검증, 비밀번호 해시
│   │   ├── config.py           # 환경변수 설정 (DATABASE_URL, OPENAI_API_KEY, JWT_SECRET)
│   │   └── db.py               # 세션/엔진
│   └── schemas/                # Pydantic 요청/응답 스키마
├── alembic/                    # DB 마이그레이션
├── tests/
├── requirements.txt
└── .env.example
```

### PostgreSQL 스키마 (REQ-B-008)

```sql
CREATE TABLE memos (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id),
    title            TEXT,
    content          TEXT NOT NULL,
    voice_url        TEXT,
    markdown_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    version          INTEGER NOT NULL DEFAULT 1,
    deleted_at       TIMESTAMPTZ
);
CREATE INDEX idx_memos_user_updated ON memos (user_id, updated_at);
```

### 인증 (REQ-B-002)

```python
# app/core/auth.py
ACCESS_TOKEN_EXPIRE = timedelta(hours=24)
REFRESH_TOKEN_EXPIRE = timedelta(days=30)

def create_tokens(user_id: UUID) -> dict:
    access = jwt.encode({"sub": str(user_id), "exp": now() + ACCESS_TOKEN_EXPIRE,
                         "type": "access"}, SECRET, algorithm="HS256")
    refresh = jwt.encode({"sub": str(user_id), "exp": now() + REFRESH_TOKEN_EXPIRE,
                          "type": "refresh"}, SECRET, algorithm="HS256")
    return {"access_token": access, "refresh_token": refresh}
```

### LWW 충돌 해결 (REQ-B-004)

```python
# PUT /memos/{id} 처리
async def upsert_memo(incoming: MemoIn, existing: Memo | None) -> Memo:
    if existing and existing.updated_at >= incoming.updated_at:
        return existing               # 서버가 더 최신 → 클라이언트 변경 무시
    # 클라이언트가 더 최신 → 덮어쓰기, version 증가
    ...
```

### 증분 동기화 (REQ-B-005)

```python
# GET /memos?since=2026-06-25T00:00:00Z
async def list_memos(user_id: UUID, since: datetime | None):
    q = select(Memo).where(Memo.user_id == user_id)
    if since:
        q = q.where(Memo.updated_at > since)  # 삭제도 deleted_at으로 함께 전파
    return await db.execute(q)
```

### Whisper 프록시 (REQ-B-006)

```python
# POST /voice/transcribe — multipart 오디오 → OpenAI Whisper
async def transcribe(file: UploadFile):
    resp = await openai_client.audio.transcriptions.create(
        model="whisper-1", file=(file.filename, await file.read()))
    return {"text": resp.text}
```

### Flutter 클라이언트 (REQ-B-009/010)

신규 파일:
| 파일 | 역할 |
|------|------|
| `lib/data/datasources/remote/memo_remote_datasource.dart` | `dio` 기반 메모 CRUD/동기화 호출 |
| `lib/data/datasources/remote/auth_remote_datasource.dart` | 회원가입/로그인/토큰 갱신 |
| `lib/domain/usecases/sync_memos.dart` | 로컬↔원격 병합(LWW) UseCase |
| `lib/core/services/sync_service.dart` | 포그라운드/저장 트리거, 오프라인 큐 관리 |

추가 패키지: `flutter_secure_storage` (JWT 저장). `dio`는 이미 프로젝트에 존재하므로 재사용. `supabase_flutter`는 **불필요**.

```dart
// sync_service.dart — 트리거 + 오프라인 큐
class SyncService {
  Future<void> onMemoSaved(Memo memo) async {
    if (await _network.isConnected()) {
      await _syncMemos();          // REQ-B-009
    } else {
      await _queue.enqueue(memo);  // REQ-B-010
    }
  }

  Future<void> onAppForeground() async {           // REQ-B-009
    if (await _network.isConnected()) {
      await _queue.flush();        // 오프라인 중 쌓인 작업 재생
      await _syncMemos(since: _lastSyncedAt);       // 증분 (REQ-B-005)
    }
  }
}
```

## 구현 순서 (Implementation Order)

방법론: TDD (RED-GREEN-REFACTOR). 백엔드 우선, 이후 Flutter 클라이언트 연동.

1. **Phase 1 — 백엔드 스캐폴드 + DB**: `backend/` FastAPI 프로젝트, `config.py`(환경변수), `db.py`, Alembic 마이그레이션으로 `users`/`memos` 스키마 생성(REQ-B-001, B-008).
2. **Phase 2 — 인증**: 회원가입/로그인/리프레시, JWT 발급/검증, 비밀번호 해시(REQ-B-002).
3. **Phase 3 — 메모 CRUD + 격리**: 5개 엔드포인트, 본인 메모 격리, 소프트 삭제(REQ-B-003).
4. **Phase 4 — 동기화**: LWW upsert(REQ-B-004), 증분 `?since=`(REQ-B-005), 삭제 전파.
5. **Phase 5 — Whisper + Share**: `POST /voice/transcribe`(REQ-B-006), `GET /memos/{id}/share`(REQ-B-007).
6. **Phase 6 — Flutter 연동**: 원격 데이터소스(메모/인증), JWT 보안 저장, `SyncMemos` UseCase, `SyncService`(포그라운드/저장 트리거 + 오프라인 큐)(REQ-B-009, B-010).

> Phase 1~5(백엔드)는 Flutter와 독립적으로 개발/테스트 가능하다. Phase 6은 백엔드 엔드포인트가 준비된 후 진행한다. SPEC-VOICE-001 Phase 5와 SPEC-WEB-MARKDOWN-001 REQ-WM-009는 본 SPEC의 백엔드를 선행 의존한다.

## MX Tag Strategy

- `create_tokens()` / JWT 검증 의존성: `@MX:ANCHOR` (모든 보호된 엔드포인트가 의존하는 인증 계약)
- LWW `upsert_memo()`: `@MX:ANCHOR` (동기화 정합성 핵심 — 클라이언트/서버 모두 의존)
- Whisper 프록시 외부 호출: `@MX:WARN` (`@MX:REASON`: 외부 API 비용/실패/타임아웃 영역)
- `SyncService.onAppForeground()` 큐 플러시: `@MX:NOTE` (오프라인 큐 재생 순서 의도)
- 비밀번호 해시 경로: `@MX:ANCHOR` (보안 불변식 — 평문 저장 금지)

## 참고 문서
- `.moai/project/product.md` — 핵심 기능 5(동기화)·6(크로스플랫폼), 사용 사례 3, Non-Goals(협업/첨부/알림), 성공 지표(동기화 < 2초, 오프라인 100%)
- `.moai/project/tech.md` — FastAPI/PostgreSQL/dio/flutter_secure_storage, 동기화 전략
- `.moai/specs/SPEC-MEMO-001/spec.md` — 동기화 대상 Memo 엔티티 (부모)
- `.moai/specs/SPEC-VOICE-001/spec.md` — REQ-V-003가 본 SPEC REQ-B-006에 의존
- `.moai/specs/SPEC-WEB-MARKDOWN-001/spec.md` — REQ-WM-009가 본 SPEC 백엔드 저장소에 의존
