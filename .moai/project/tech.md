---
title: Technology Stack
tags: [technology, framework, flutter, fastapi, database, deployment]
created: 2026-06-25
modified: 2026-06-25
aliases: [기술스택, 기술선택, 개발환경]
---

# Technology Stack: memo-everywhere

**관련 문서**: [[index]] | [[product]] | [[structure]]

---

## 프로그래밍 언어

### Primary: Dart
- **목적**: Flutter 프레임워크용 언어
- **버전**: 3.2.0 이상
- **특징**: 타입 안전, JIT/AOT 컴파일, 빠른 성능
- **패키지 관리자**: pub.dev

### Backend: Python
- **목적**: FastAPI 서버 개발
- **버전**: 3.11 이상
- **특징**: 빠른 개발, 풍부한 라이브러리
- **패키지 관리자**: pip, requirements.txt

### Configuration: YAML, JSON
- 설정 파일: YAML
- API 응답/i18n: JSON

---

## 프레임워크 및 플랫폼

### Flutter Framework #framework/flutter
- **버전**: 3.22 LTS 이상 (권장)
- **목적**: iOS, Android, macOS, Windows, Linux, Web 크로스플랫폼 개발
- **공식 사이트**: https://flutter.dev
- **장점**:
  - 단일 코드베이스로 6개 플랫폼 지원
  - 빠른 개발 (Hot Reload)
  - 풍부한 위젯 라이브러리
  - 높은 성능

### FastAPI Framework #framework/fastapi
- **버전**: 0.104 이상
- **목적**: 현대적인 REST API 개발
- **공식 사이트**: https://fastapi.tiangolo.com
- **특징**:
  - 자동 API 문서 (Swagger, ReDoc)
  - 비동기 지원 (asyncio)
  - 빠른 성능 (Uvicorn 서버)
  - 타입 힌트 기반 검증 (Pydantic)

---

## 음성 처리 (Voice / STT) #feature/voice

### 옵션 비교

| 옵션 | 장점 | 단점 | 권장 |
|------|------|------|------|
| **Whisper API** | 높은 정확도, 다국어 | 인터넷 필수, 비용 | 품질 중시 |
| **디바이스 STT** | 오프라인, 무료, 빠름 | 정확도 편차 | 속도 중시 |
| **하이브리드** | 균형 잡힌 선택 | 구현 복잡 | ⭐ 권장 |

### 권장: 하이브리드 접근 (온디바이스 + 클라우드)

#### 기본: 디바이스 네이티브 STT
```
Flutter App
  ↓ record audio
  ↓ send to device STT
  ↓ receive text
Local Storage (Hive)
```

**플랫폼별 구현**:
- **iOS**: `Speech.framework` (Apple 네이티브)
- **Android**: `android.speech.SpeechRecognizer`
- **Windows/macOS**: Platform channel → 네이티브 API
- **Linux**: PulseAudio + 로컬 모델
- **Web**: Web Speech API

**Flutter 패키지**: `speech_to_text` ⭐ (권장)

#### 선택: Whisper API (클라우드 STT)
```
Flutter App (optional)
  ↓ record audio (high quality)
  ↓ send to FastAPI backend
FastAPI Server
  ↓ forward to OpenAI Whisper API
  ↓ receive transcription
  ↓ save to database
  ↓ sync to app
Flutter App
```

**공급자**: OpenAI Whisper API
- **비용**: $0.02/분 (약 1000분에 $20)
- **정확도**: 95% 이상
- **다국어**: 99개 언어 지원
- **인증**: `openai` Python 라이브러리

**설정**:
```python
# backend/.env
OPENAI_API_KEY=sk-...
WHISPER_MODEL=whisper-1
```

---

## 오디오 녹음 (Audio Recording)

### 권장 패키지: `record` #package/audio

```dart
final audioRecorder = AudioRecorder();
await audioRecorder.start(
  const RecordConfig(
    encoder: AudioEncoder.aac,
    bitRate: 128000,
    sampleRate: 16000, // STT 최적화
  ),
);
```

**코덱 선택**:
| 플랫폼 | 코덱 | 확장자 | 비고 |
|--------|------|-------|------|
| iOS | AAC | .m4a | 기본 |
| Android | MP4/AAC | .mp4 | Google 권장 |
| Web | WAV | .wav | 브라우저 제한 |
| macOS | AAC | .m4a | 기본 |
| Windows | WAV | .wav | 호환성 |
| Linux | WAV | .wav | 광범위 지원 |

### 대체: `flutter_sound`
- 풍부한 기능 (재생, 일시 정지, 타이머)
- 더 많은 코덱 지원
- 더 복잡한 API

---

## 클라우드 동기화 (Cloud Sync) #feature/sync

### 아키텍처 선택

#### 옵션 1: Firebase Firestore (서버리스) 
- **장점**: 완전 관리형, 실시간 업데이트, 인증 통합
- **단점**: 벤더 락인, 복잡한 쿼리 제한
- **Flutter**: `cloud_firestore`, `firebase_auth`
- **가격**: 무료 티어 충분

#### 옵션 2: Supabase (PostgreSQL 기반)
- **장점**: Firebase 대안, 벡터 검색, 오픈소스
- **단점**: 자체 관리 필요 시 스케일링 도전
- **Flutter**: `supabase_flutter`
- **가격**: 저렴한 호스팅

#### 옵션 3: 커스텀 FastAPI + PostgreSQL ⭐ 권장
- **장점**: 완전한 제어, 복잡한 쿼리 가능, 비용 효율
- **단점**: 서버 관리 필요
- **아키텍처**:

```
Flutter App (로컬 Hive)
    ↓ sync HTTP requests
FastAPI Server (데이터 처리)
    ↓ read/write
PostgreSQL (영구 저장소)
```

**동기화 전략**:
- **Version Vectoring**: 각 메모에 버전 번호
- **Last-Write-Wins (LWW)**: 최신 수정시간 기준
- **Incremental Sync**: 변경된 것만 동기

---

## 로컬 데이터베이스 (Local Storage)

### 옵션 비교

| DB | 타입 | 사용성 | 성능 | 검색 | 권장 |
|----|------|--------|------|------|------|
| **Hive** | 키-값 | ⭐⭐⭐⭐⭐ | 매우빠름 | 기본 | 초기 개발 |
| **Isar** | 관계형 | ⭐⭐⭐⭐ | 매우빠름 | 고급 | 확장 시 |
| **SQLite** | SQL | ⭐⭐⭐ | 빠름 | 표준 | 대안 |

### 권장: Hive (초기) → Isar (확장)

#### Phase 1: Hive #package/hive
```dart
// 간단한 메모 저장
final box = Hive.box<Memo>('memos');
box.put('id', memo);
```

**장점**:
- 매우 가볍고 빠름
- Dart 친화적
- 타입 안전
- 구현 간단

**단점**:
- 복잡한 쿼리 제한
- 검색 기능 제한

#### Phase 2: Isar (필요 시 마이그레이션)
```dart
// 관계형 쿼리
final searchResults = isar.memos
    .filter()
    .titleContains(query)
    .and()
    .tagsContains(tag)
    .findAll();
```

**장점**:
- SQL 같은 쿼리
- 복잡한 필터링
- 빠른 검색

---

## 상태 관리 (State Management)

### 권장: Riverpod #package/riverpod

```dart
// 동기화된 메모 목록
final memoListProvider = FutureProvider((ref) async {
  final repository = ref.watch(memoRepositoryProvider);
  return repository.getMemos();
});

// 단일 메모 상태
final selectedMemoProvider = StateProvider<Memo?>((ref) => null);

// 캐시된 데이터
final cachedMemoProvider = FutureProvider.autoDispose((ref) async {
  return await ref.watch(memoRepositoryProvider).getMemos();
});
```

**선택 이유**:
- 함수형, 불변성
- 의존성 주입 내장
- 테스트 용이
- Provider 진화판 (더 강력함)

**패키지**: `riverpod`, `flutter_riverpod`, `riverpod_generator`

### 대체: BLoC (복잡한 로직)
- 이벤트-상태 기반
- 스트림 중심
- 엄격한 아키텍처
- 대규모 팀 협업 시 권장

---

## 라우팅 및 네비게이션

### 권장: go_router #package/router

```dart
// URL 기반 라우팅
GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => HomePage(),
    ),
    GoRoute(
      path: '/memo/:id',
      builder: (context, state) => MemoDetailPage(
        id: state.params['id'],
      ),
    ),
  ],
);
```

**장점**:
- URL 기반 (웹, 딥링크 지원)
- 상태 관리 통합
- 네비게이션 스택 관리
- 다중 플랫폼 지원

---

## 기타 필수 패키지

### 음성 처리 (Voice & STT) #package/voice

| 패키지 | 목적 | 버전 |
|--------|------|------|
| `record` | 오디오 녹음 (플랫폼 네이티브 코덱) | 7.0.0+ |
| `speech_to_text` | 음성-텍스트 변환 (네이티브 STT) | 7.0.0+ |

### 네트워크 및 인증 #package/network

| 패키지 | 목적 | 버전 |
|--------|------|------|
| `dio` | HTTP 클라이언트 (권장) | 5.3.0+ |
| `flutter_secure_storage` | 안전한 토큰 저장 (KeyChain/Keystore) | 9.0.0+ |
| `connectivity_plus` | 네트워크 상태 감지 | 5.0.0+ |
| `http` | 표준 HTTP 라이브러리 | 1.1.0+ |

```dart
// dio 사용
final dio = Dio();
final response = await dio.get('https://api.example.com/memos');
```

### 다국어 (i18n)

| 패키지 | 특징 |
|--------|------|
| `easy_localization` | JSON 기반, 런타임 언어 전환 |
| `gen_lang` | 타입 안전, 코드 생성 |

```dart
'hello'.tr() // 현재 언어로 번역
```

### 데이터 처리

| 패키지 | 목적 |
|--------|------|
| `json_serializable` | JSON ↔ Dart 객체 자동 생성 |
| `intl` | 날짜, 숫자 포맷팅 |
| `equatable` | 객체 비교 간소화 |

### 로깅 및 분석

| 패키지 | 목적 |
|--------|------|
| `logger` | 콘솔 로깅 (Sentry 대체) |
| `firebase_analytics` | 사용자 분석 (선택) |

### 테스트

| 패키지 | 목적 |
|--------|------|
| `flutter_test` | 기본 테스트 프레임워크 |
| `mocktail` | 모의 객체 (mockito 권장 패키지) |
| `integration_test` | 엔드-투-엔드 테스트 |

---

## 백엔드 스택 (FastAPI)

### 핵심 라이브러리

```text
FastAPI==0.104.0           # 웹 프레임워크
sqlalchemy==2.0.0          # ORM
alembic==1.13.0            # DB 마이그레이션
pydantic==2.0.0            # 검증
python-jose==3.3.0         # JWT 토큰
openai==1.0.0              # Whisper API
python-dotenv==1.0.0       # 환경 변수
```

### 데이터베이스: PostgreSQL #database/postgres

```sql
-- 메모 테이블
CREATE TABLE memos (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    title TEXT,
    content TEXT,
    voice_url TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    synced_at TIMESTAMP,
    version INT DEFAULT 0 -- 버전 관리
);

-- 태그 테이블
CREATE TABLE tags (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP
);
```

**이유**:
- 강력한 검색 (ILIKE, 전문 검색)
- JSON 지원 (메타데이터)
- 트리거 지원 (동기화)
- 관계형 데이터 강점

### 서버 배포

| 환경 | 방식 |
|------|------|
| **로컬 개발** | Uvicorn + SQLite |
| **프로덕션** | Docker + Kubernetes 또는 Cloud Run |

```bash
# 로컬 실행
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Docker
docker build -t memo-api .
docker run -p 8000:8000 memo-api
```

---

## 개발 환경 요구사항

### 필수 설치

| 도구 | 버전 | 목적 |
|------|------|------|
| **Flutter SDK** | 3.22+ | 모바일/데스크톱 개발 |
| **Dart SDK** | Flutter 포함 | 언어 런타임 |
| **Python** | 3.11+ | 백엔드 개발 |
| **PostgreSQL** | 14+ | 데이터베이스 |
| **Git** | 2.40+ | 버전 관리 |
| **VS Code** | 최신 | 에디터 (권장) |

### 설치 가이드

```bash
# Flutter 설치
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.22.0-stable.zip
unzip flutter_macos_arm64_3.22.0-stable.zip
export PATH="$PATH:$PWD/flutter/bin"
flutter doctor

# Python 가상 환경
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
pip install -r requirements.txt

# PostgreSQL (macOS Homebrew)
brew install postgresql@14
brew services start postgresql@14
```

### 플랫폼별 추가 요구사항

| 플랫폼 | 요구사항 |
|--------|---------|
| **iOS** | macOS 12+, Xcode 14+, iOS 11.0+ 타겟 |
| **Android** | Android SDK 21+, 에뮬레이터 또는 실 기기 |
| **macOS** | macOS 10.15+, Xcode |
| **Windows** | Windows 10+, Visual Studio 빌드 도구 |
| **Linux** | GTK 3.0+, Ubuntu 18.04+ |
| **Web** | 최신 브라우저 (Chrome, Safari, Firefox) |

---

## 개발 워크플로우 명령어

### Flutter 프로젝트

```bash
# 프로젝트 생성
flutter create memo_everywhere

# 의존성 설치
flutter pub get

# 코드 생성 (JSON, Riverpod)
flutter pub run build_runner build --delete-conflicting-outputs

# 앱 실행 (실 기기 필요)
flutter run

# 테스트
flutter test
flutter test integration_test/

# 빌드
flutter build ios      # iOS
flutter build apk      # Android
flutter build web      # Web
flutter build linux    # Linux
flutter build macos    # macOS
flutter build windows  # Windows

# 린트
flutter analyze
dart fix --apply
```

### FastAPI 백엔드

```bash
# 개발 서버 실행
uvicorn app.main:app --reload

# DB 마이그레이션
alembic upgrade head

# 테스트
pytest

# 타입 체크
mypy app/
```

---

## 환경 변수 설정

### Flutter `.env`
```
BACKEND_API_URL=https://api.memo-everywhere.com
ENABLE_WHISPER_API=false
DEBUG_MODE=false
```

### FastAPI `.env`
```
# 데이터베이스
DATABASE_URL=postgresql://user:pass@localhost:5432/memo_db
DATABASE_ECHO=false

# API 보안
SECRET_KEY=your-secret-key-here
JWT_EXPIRATION_HOURS=24

# OpenAI Whisper
OPENAI_API_KEY=sk-...
WHISPER_MODEL=whisper-1

# 환경
ENVIRONMENT=development
LOG_LEVEL=INFO
```

### 로드 방식
- **Flutter**: `flutter_dotenv` 패키지
- **Python**: `python-dotenv` 라이브러리

---

## 버전 관리 정책

| 컴포넌트 | 업그레이드 주기 | 기준 |
|---------|--------|------|
| **Flutter** | 분기별 | 새 LTS 릴리스 시 |
| **Python** | 연 1회 | 보안 업데이트 |
| **주요 패키지** | 분기별 | 호환성 확인 후 |
| **보안 업데이트** | 즉시 | Patch 버전 |

---

## 참고 문서

- [[product]] - 기능 정의
- [[structure]] - 프로젝트 구조
- [[voice-processing]] - 음성 처리 상세
- [[database-options]] - 데이터베이스 선택
- [[sync-strategy]] - 동기화 전략
