# memo-everywhere

크로스 플랫폼 Flutter 메모 앱. iOS 11.0 이상, Android SDK 21 이상에서 완벽하게 동작하는 오프라인 우선(offline-first) 텍스트 메모 관리 애플리케이션입니다.

## 개요

**memo-everywhere**는 사용자가 언제 어디서나 메모를 작성, 조회, 수정, 삭제할 수 있는 간단하고 빠른 메모 앱입니다. 모든 데이터는 Hive 로컬 저장소에 저장되어 네트워크 연결 없이도 완벽하게 동작합니다.

### 주요 특징

- **CRUD 기능**: 메모 생성, 조회, 수정, 삭제
- **음성 메모**: 음성 녹음 + 자동 텍스트 변환(STT) — 네이티브 STT 또는 클라우드 Whisper API (실제 구현 완료)
- **선택적 로그인**: 앱은 로그인 없이도 완전히 동작하며, 로그인 시에만 동기화 및 음성변환 활성화
  - 세션 자동 복원 (재시작 시 재로그인 불필요)
- **양방향 크로스디바이스 동기화**: FastAPI 백엔드 + PostgreSQL로 모든 기기 간 30초 주기 자동 폴링 동기화
  - Last-Write-Wins (LWW) 충돌 해결
  - 영속 오프라인 큐 (강제종료 후 재시작해도 유실 없음)
  - Access 토큰 자동 갱신 (401 시 refresh 토큰으로 자동 재발급)
  - 소프트 삭제 지원 (include_deleted 쿼리)
- **실시간 검색**: 제목/내용 키워드 검색 — 대소문자 무시, 300ms 디바운스
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
- **record**: 음성 녹음 (플랫폼별 코덱: AAC/MP4/WAV)
- **speech_to_text**: 네이티브 STT (ko-KR, en-US)
- **flutter_secure_storage**: 안전한 토큰 저장 (Keychain/Keystore)
- **connectivity_plus**: 네트워크 상태 감지
- **dio**: HTTP 클라이언트 (API 통신, JWT 인터셉터 포함)
- **path_provider**: 오디오 파일 경로 관리

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

환경 변수 설정:
```bash
# backend/.env 생성 (gitignore 보호)
OPENAI_API_KEY=sk-...
JWT_SECRET=your-secret-key
```

데이터베이스 마이그레이션:
```bash
alembic upgrade head
```

백엔드 실행:
```bash
# 기본 포트 (포트 충돌 시 --port 8001 등으로 조정)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**참고**: 포트 8000이 사용 중이면 다른 포트(예: 8001)로 지정하고, Flutter 앱 실행 시 `--dart-define=API_BASE_URL`으로 동일한 주소 전달

### 앱 실행

**API 기본 URL 설정** (필수):
```bash
# 백엔드를 실행 중인 서버 주소로 변경
# 같은 Wi-Fi의 LAN IP 또는 Tailscale IP 사용 가능
flutter run --dart-define=API_BASE_URL=http://<host>:8000

# 예시
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000  # LAN IP
flutter run --dart-define=API_BASE_URL=http://100.64.x.x:8000    # Tailscale
```

**iOS**:
```bash
flutter run -d iphone --dart-define=API_BASE_URL=http://<host>:8000
```

**Android** (실기기):
```bash
# 실기기 확인
flutter devices

# 특정 기기에서 실행
flutter run -d <device-id> --dart-define=API_BASE_URL=http://<host>:8000
```

**macOS**:
```bash
# macOS 개발 서명 설정 필수 (아래 참고)
flutter run -d macos --dart-define=API_BASE_URL=http://<host>:8000
```

**Web**:
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://<host>:8000
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

**SPEC-WEB-MARKDOWN-001: Flutter Web 지원** — ✅ 완료 (마크다운 렌더링 제외)

Flutter Web 플랫폼 지원을 정의합니다. 상세 내용은 `.moai/specs/SPEC-WEB-MARKDOWN-001/spec.md`를 참조하세요.

- 플랫폼: Web 지원 (`web/` 디렉토리, 반응형 레이아웃)
- 마크다운 렌더링: 철회됨 — 순수 텍스트 편집 방식 유지
- 테스트: 112개

## 개발 환경 설정

### 백엔드 및 앱 연결

**프론트엔드(앱)와 백엔드 서버 통신**:
1. **같은 로컬 네트워크 (Wi-Fi)**: LAN IP로 연결
   ```bash
   # 백엔드 서버의 LAN IP 확인 (예: 192.168.1.10)
   # 터미널: ifconfig | grep "inet " (macOS/Linux)
   
   # 앱에서 같은 LAN의 다른 기기에 접속
   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
   ```

2. **원격 네트워크 (Tailscale)**: Tailscale IP로 연결
   ```bash
   # Tailscale 설치 후 백엔드 서버의 Tailscale IP 확인 (예: 100.64.x.x)
   # 앱에서 Tailscale을 통해 연결
   flutter run --dart-define=API_BASE_URL=http://100.64.x.x:8000
   ```

### macOS 빌드 설정

**Keychain entitlements 활성화** (선택적 로그인, flutter_secure_storage용):
1. `macos/Runner/Configs/Signing.xcconfig` 파일 생성 (gitignore 보호):
   ```bash
   DEVELOPMENT_TEAM = <본인 Apple Team ID>
   ```
2. Apple Team ID는 Apple Developer Portal에서 확인 (숫자/알파벳 조합)
3. Xcode에서 "Team" 설정으로 자동 서명 활성화

**결과**: macOS 11.0 이상에서 Keychain 기반 토큰 저장 가능

### 로그인 활성화

**기본 동작**: 로그인 없이 모든 메모 기능이 로컬로만 작동
- 메모 CRUD: ✅ (로컬 Hive)
- 음성 녹음: ✅ (디바이스 STT)
- 동기화: ❌ (로그인 필요)
- Whisper STT: ❌ (로그인 필요)

**로그인 후 활성화**:
- 홈 AppBar의 계정 아이콘 클릭 → 로그인 화면
- 회원가입 또는 기존 계정 로그인
- 로그인 후 30초 폴링 자동 시작, Whisper STT 사용 가능

---

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

**최근 업데이트**: 2026-06-26 (v0.4.1 — 세션 자동 복원 + 영속 오프라인 큐 + 토큰 자동 갱신)
- Flutter 테스트: 222개 통과
- Backend 테스트 (pytest): 26개 통과
