# memo-everywhere

크로스 플랫폼 Flutter 메모 앱. iOS 11.0 이상, Android SDK 21 이상에서 완벽하게 동작하는 오프라인 우선(offline-first) 텍스트 메모 관리 애플리케이션입니다.

## 개요

**memo-everywhere**는 사용자가 언제 어디서나 메모를 작성, 조회, 수정, 삭제할 수 있는 간단하고 빠른 메모 앱입니다. 모든 데이터는 Hive 로컬 저장소에 저장되어 네트워크 연결 없이도 완벽하게 동작합니다.

### 주요 특징

- **CRUD 기능**: 메모 생성, 조회, 수정, 삭제
- **음성 메모**: 음성 녹음 + 자동 텍스트 변환(STT) — 네이티브 및 클라우드 기반
- **실시간 검색**: 제목/내용 키워드 검색 — 대소문자 무시, 300ms 디바운스
- **마크다운 미리보기**: 읽기 모드에서 마크다운 렌더링 (편집은 순수 텍스트)
- **크로스디바이스 동기화**: FastAPI 백엔드 + PostgreSQL로 모든 기기 간 실시간 동기화
- **오프라인 지원**: Hive 로컬 저장소 - 항상 데이터에 접근 가능, 온라인 복귀 시 자동 동기화
- **크로스 플랫폼**: iOS, Android, macOS, Web에서 동일하게 동작
- **깔끔한 UI**: 직관적인 인터페이스와 빠른 성능
- **자동 정렬**: 최근 수정 순서로 자동 정렬

## 기술 스택

### 프론트엔드 (Flutter/Dart)
- **Flutter**: 3.22 LTS 이상
- **Dart**: 3.2.0 이상
- **Riverpod**: 반응형 상태 관리 (`@riverpod` 코드 생성)
- **go_router**: 타입 안전 라우팅
- **Hive**: 로컬 key-value 저장소
- **flutter_markdown**: 마크다운 렌더링
- **record**: 음성 녹음 (플랫폼별 코덱)
- **speech_to_text**: 네이티브 STT (ko-KR, en-US)
- **flutter_secure_storage**: 안전한 토큰 저장
- **connectivity_plus**: 네트워크 상태 감지
- **dio**: HTTP 클라이언트 (API 통신)

### 백엔드 (FastAPI/Python)
- **FastAPI**: 0.104 이상 (REST API 프레임워크)
- **SQLAlchemy**: 2.0 이상 (ORM)
- **Alembic**: 데이터베이스 마이그레이션
- **PostgreSQL**: 14 이상 (관계형 데이터베이스)
- **python-jose**: JWT 인증
- **bcrypt**: 비밀번호 암호화
- **openai**: Whisper API (클라우드 STT)

### 아키텍처
- **Clean Architecture**: Presentation → Domain ← Data 계층 분리
- Domain 계층은 외부 프레임워크에 의존하지 않음
- 테스트 가능성과 유지보수성 최우선

### 개발 도구
- **build_runner**: 코드 생성 (Hive TypeAdapter, Riverpod)
- **flutter_lints**: Lint 규칙

## 실행 방법

### 사전 요구사항

**Flutter 클라이언트**:
- Flutter SDK 3.22 LTS 이상
- Dart SDK 3.2.0 이상
- iOS 개발 환경 (macOS 필수)
- Android Studio 또는 Android NDK (Android 개발)

**FastAPI 백엔드**:
- Python 3.11 이상
- PostgreSQL 14 이상
- pip (또는 가상 환경)

### Flutter 클라이언트 설정

의존성 설치:
```bash
flutter pub get
```

코드 생성 (Hive + Riverpod):
```bash
dart run build_runner build
```

또는 개발 중 자동으로 감시:
```bash
dart run build_runner watch --delete-conflicting-outputs
```

### FastAPI 백엔드 설정

Python 가상 환경 생성 및 활성화:
```bash
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
venv\Scripts\activate     # Windows
```

의존성 설치:
```bash
pip install -r requirements.txt
```

데이터베이스 마이그레이션:
```bash
alembic upgrade head
```

백엔드 실행:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 앱 실행

**iOS**:
```bash
flutter run -d iphone
```

**Android**:
```bash
flutter run -d android
```

**Web**:
```bash
flutter run -d chrome
```
또는
```bash
flutter build web
```

**특정 기기**:
```bash
flutter devices                    # 사용 가능한 기기 목록
flutter run -d <device-id>        # 특정 기기에서 실행
```

## 테스트 실행

전체 테스트 스위트 실행:
```bash
flutter test
```

특정 테스트 파일 실행:
```bash
flutter test test/unit/domain/entities/memo_test.dart
```

테스트 커버리지 포함:
```bash
flutter test --coverage
```

## 프로젝트 구조

```
lib/
├── core/                          # 공유 설정
│   ├── constants/
│   │   └── app_constants.dart    # 애플리케이션 상수
│   └── router/
│       └── app_router.dart       # go_router 설정
├── domain/                        # 비즈니스 로직 (외부 의존성 없음)
│   ├── entities/
│   │   └── memo.dart             # Memo 값 객체
│   ├── repositories/
│   │   └── memo_repository.dart  # 저장소 인터페이스
│   └── usecases/
│       ├── create_memo.dart
│       ├── get_memos.dart
│       ├── update_memo.dart
│       ├── delete_memo.dart
│       └── search_memos.dart     # 인메모리 키워드 필터링
├── data/                          # 데이터 계층 (Hive)
│   ├── datasources/
│   │   └── local/
│   │       └── memo_local_datasource.dart
│   ├── models/
│   │   └── memo_model.dart
│   └── repositories/
│       └── memo_repository_impl.dart
├── presentation/                  # UI 계층 (Riverpod)
│   ├── pages/
│   │   ├── home_page.dart
│   │   └── memo_editor_page.dart
│   ├── state/
│   │   └── memo_provider.dart
│   └── widgets/
│       └── memo_card.dart
└── main.dart                      # 진입점 (Hive 초기화)

test/
├── unit/
│   ├── domain/
│   ├── data/
│   └── ...
└── widget/
    └── ...
```

## SPEC 문서

**SPEC-MEMO-001: 텍스트 메모 CRUD MVP** — ✅ 완료

텍스트 메모의 기본 CRUD 기능을 정의합니다. 상세 내용은 `.moai/specs/SPEC-MEMO-001/spec.md`를 참조하세요.

- 요구사항: 10개 (EARS 형식)
- 구현 파일: 17개
- 테스트: 57개

**SPEC-SEARCH-001: 메모 검색 기능** — ✅ 완료

제목/내용 키워드 기반 인메모리 검색 기능을 정의합니다. 상세 내용은 `.moai/specs/SPEC-SEARCH-001/spec.md`를 참조하세요.

- 요구사항: 7개 (EARS 형식), 인수 기준 6개
- 신규 파일: `SearchMemos` UseCase, 검색 Provider, 위젯 테스트
- 테스트: 12개 신규 (T-001~T-012)

**SPEC-BACKEND-001: FastAPI 백엔드 + 크로스디바이스 동기화** — ✅ 완료

FastAPI 기반 REST API 서버와 클라이언트 동기화 기능을 정의합니다. 상세 내용은 `.moai/specs/SPEC-BACKEND-001/spec.md`를 참조하세요.

- 요구사항: 15개 (EARS 형식)
- 백엔드 엔드포인트: 5개 (JWT 인증, 메모 CRUD, 음성 STT)
- Flutter 클라이언트: 토큰 관리, 동기화 서비스
- 테스트: 21개 (pytest)

**SPEC-VOICE-001: 음성 메모 녹음 + STT** — ✅ 완료

음성 녹음 및 음성-텍스트 변환 기능을 정의합니다. 상세 내용은 `.moai/specs/SPEC-VOICE-001/spec.md`를 참조하세요.

- 요구사항: 12개 (EARS 형식)
- 음성 녹음: 플랫폼별 코덱 지원 (AAC/MP4/WAV)
- STT: 네이티브 (speech_to_text) + 클라우드 (Whisper API)
- 테스트: 109개

**SPEC-WEB-MARKDOWN-001: Flutter Web + 마크다운 렌더링** — ✅ 완료

Flutter Web 플랫폼 지원 및 마크다운 미리보기 기능을 정의합니다. 상세 내용은 `.moai/specs/SPEC-WEB-MARKDOWN-001/spec.md`를 참조하세요.

- 요구사항: 8개 (EARS 형식)
- 플랫폼: Web 지원 (`web/` 디렉토리, 반응형 레이아웃)
- 마크다운 렌더링: 읽기 모드 (편집은 순수 텍스트)
- 테스트: 117개

## 개발 가이드

### Clean Architecture 규칙

**의존성 방향**:
```
Presentation → Domain ← Data
```

Domain 계층은 어떤 프레임워크에도 의존하지 않습니다.

### TDD 워크플로우

1. **RED**: 실패하는 테스트 작성
2. **GREEN**: 테스트를 통과하는 최소 구현
3. **REFACTOR**: 코드 품질 개선 (테스트는 통과 유지)

### MX 태그

중요한 코드 위치에 주석 추가:

- `@MX:ANCHOR` - 높은 fan_in을 가진 함수/인터페이스
- `@MX:NOTE` - 복잡한 로직의 설명
- `@MX:WARN` - 주의가 필요한 위험 지역

## 파일 및 라이선스

MIT 라이선스

## 기여 가이드

1. SPEC 문서 검토
2. 기능 브랜치 생성
3. TDD 방식으로 구현
4. 테스트 통과 확인
5. PR 생성

---

**최근 업데이트**: 2026-06-25 (3가지 SPEC 완료 — 음성 메모, 백엔드 동기화, Web 플랫폼 추가)
