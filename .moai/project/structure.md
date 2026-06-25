---
title: Project Structure
tags: [architecture, structure, flutter, backend, clean-architecture]
created: 2026-06-25
modified: 2026-06-25
aliases: [프로젝트구조, 디렉토리구조, 폴더구조]
---

# Project Structure: memo-everywhere

**관련 문서**: [[index]] | [[product]] | [[tech]]

---

## 전체 디렉토리 구조

```
memo-everywhere/
├── lib/                          # Flutter Dart 소스 코드
│   ├── main.dart                 # 애플리케이션 진입점
│   ├── core/                     # 핵심 기능 (유틸리티, 상수, 헬퍼)
│   │   ├── constants/            # 애플리케이션 상수
│   │   ├── extensions/           # Dart 확장 메서드
│   │   ├── network/              # 네트워크 설정
│   │   │   ├── dio_config.dart   # Dio + JWT 인터셉터
│   │   │   └── network_checker.dart  # 온/오프라인 감지
│   │   ├── services/             # 애플리케이션 서비스
│   │   │   ├── sync_service.dart      # 양방향 동기화
│   │   │   └── sync_poller.dart       # 30초 폴링
│   │   ├── utils/                # 유틸리티 함수 (포맷팅, 검증 등)
│   │   └── theme/                # 테마 및 스타일 (색상, 폰트 등)
│   ├── data/                     # 데이터 계층 (API, 로컬 DB, 모델)
│   │   ├── datasources/          # 데이터 소스
│   │   │   ├── local/            # Hive/Isar 로컬 데이터베이스
│   │   │   │   └── audio_local_datasource.dart  # 오디오 파일 관리
│   │   │   ├── remote/           # REST API 클라이언트
│   │   │   │   ├── auth_remote_datasource.dart  # JWT 로그인/회원가입/리프레시
│   │   │   │   ├── memo_remote_datasource.dart  # 메모 CRUD + 양방향 동기화
│   │   │   │   ├── backend_stt_service.dart # Whisper API 프록시
│   │   │   │   └── sync_store.dart         # 오프라인 큐 관리
│   │   │   └── cache/            # 캐시 관리
│   │   ├── models/               # JSON 직렬화 모델
│   │   │   ├── memo_model.dart   # (HiveField 5: deletedAt 추가)
│   │   │   ├── tag_model.dart
│   │   │   └── user_model.dart
│   │   └── repositories/         # 저장소 (데이터 계층 추상화)
│   │       ├── memo_repository.dart
│   │       ├── tag_repository.dart
│   │       └── auth_repository.dart
│   ├── domain/                   # 도메인 계층 (비즈니스 로직)
│   │   ├── entities/             # 도메인 엔티티 (모델과 분리)
│   │   │   ├── memo.dart
│   │   │   ├── tag.dart
│   │   │   └── user.dart
│   │   ├── repositories/         # 저장소 인터페이스 (추상화)
│   │   └── usecases/             # 비즈니스 로직 (Use Cases)
│   │       ├── create_memo.dart
│   │       ├── search_memos.dart
│   │       ├── record_voice.dart
│   │       ├── sync_memos.dart   # 양방향 동기화 (push + pull)
│   ├── presentation/             # 프레젠테이션 계층 (UI)
│   │   ├── pages/                # 완전한 화면 (페이지)
│   │   │   ├── home_page.dart
│   │   │   ├── auth_screen.dart        # 로그인/회원가입 (선택적)
│   │   │   ├── memo_editor_page.dart    # 순수 텍스트 작성/편집
│   │   │   ├── search_page.dart
│   │   │   ├── voice_record_page.dart   # 음성 녹음 UI
│   │   │   └── settings_page.dart
│   │   ├── widgets/              # 재사용 가능한 위젯
│   │   │   ├── memo_card.dart
│   │   │   ├── tag_chip.dart
│   │   │   ├── voice_recorder.dart      # 녹음/정지/재생 버튼
│   │   │   └── search_bar.dart
│   │   ├── state/                # 상태 관리 (Riverpod)
│   │   │   ├── memo_provider.dart
│   │   │   ├── tag_provider.dart
│   │   │   ├── search_provider.dart
│   │   │   ├── voice_provider.dart      # 음성 녹음 상태
│   │   │   ├── auth_provider.dart       # JWT 토큰 + 로그인 상태
│   │   │   └── sync_provider.dart       # 동기화 상태 (30초 폴링)
│   │   └── bloc/                 # BLoC 상태 관리 (선택적)
│   │       └── memo_bloc/
│   └── shared/                   # 공유 리소스
│       ├── config/               # 앱 설정 (API 기본 URL, 환경)
│       └── services/             # 공유 서비스 (로깅, 분석)
├── test/                         # 유닛 및 위젯 테스트
│   ├── unit/                     # 로직 테스트
│   │   ├── usecases/
│   │   └── services/
│   └── widget/                   # UI 컴포넌트 테스트
├── integration_test/             # 통합 테스트
├── assets/                       # 정적 리소스
│   ├── images/
│   ├── fonts/
│   └── translations/             # i18n 다국어 JSON
│       ├── en.json
│       └── ko.json
├── docs/                         # 마크다운 문서 (Obsidian vault)
├── pubspec.yaml                  # Flutter 의존성 정의
├── analysis_options.yaml         # Lint 규칙 설정
├── .env.example                  # 환경 변수 템플릿
└── README.md                     # 프로젝트 README
```

---

## 백엔드 서버 구조

```
backend/                          # FastAPI 백엔드 서버
├── app/
│   ├── main.py                   # FastAPI 진입점
│   ├── core/
│   │   ├── config.py             # 환경 설정 (DB, JWT, OpenAI)
│   │   ├── auth.py               # JWT 인증 로직 (encode/decode)
│   │   └── db.py                 # 데이터베이스 연결
│   ├── api/
│   │   ├── routes/
│   │   │   ├── auth.py           # 인증 엔드포인트 (register, login, refresh)
│   │   │   ├── memos.py          # 메모 CRUD + 동기화 엔드포인트
│   │   │   │                     #  GET /memos (with ?since=&include_deleted)
│   │   │   │                     #  PUT /memos/{id} (upsert by client uuid)
│   │   │   │                     #  DELETE /memos/{id} (soft delete)
│   │   │   └── voice.py          # 음성 처리 (POST /voice/transcribe)
│   ├── models/                   # SQLAlchemy ORM 모델
│   │   ├── memo.py               # (fields: id, user_id, title, content, deletedAt...)
│   │   └── user.py
│   ├── schemas/                  # Pydantic 스키마 (요청/응답)
│   │   ├── memo.py
│   │   ├── user.py
│   │   └── auth.py
│   └── services/                 # 비즈니스 로직
│       ├── auth_service.py       # JWT (encode/decode), bcrypt 비밀번호
│       ├── memo_service.py       # 메모 CRUD + LWW 동기화 + 증분 폴링
│       └── voice_service.py      # OpenAI Whisper API 호출
├── alembic/                      # 데이터베이스 마이그레이션
│   ├── versions/                 # 마이그레이션 파일
│   └── env.py
├── tests/
│   └── test_api.py               # API 엔드포인트 테스트 (26개)
├── requirements.txt              # Python 의존성
├── .env                          # 환경 변수 (gitignore 보호)
│                                 #  OPENAI_API_KEY, JWT_SECRET
├── .env.example                  # 환경 변수 템플릿
├── .gitignore                    # .env, *.db, venv/, __pycache__ 보호
└── alembic.ini                   # Alembic 설정
```

**macOS 빌드 설정**:
```
macos/Runner/Configs/
├── Signing.xcconfig              # (gitignore) DEVELOPMENT_TEAM = <Apple Team ID>
└── ...
```

---

## Clean Architecture 계층 설명

### #layer/presentation - 프레젠테이션 계층
**위치**: `lib/presentation/`

**책임**:
- 사용자 인터페이스 (Pages, Widgets)
- 상태 관리 (Riverpod Providers, BLoC)
- 사용자 입력 처리
- UI 렌더링

**의존성**: Domain, Data 계층에 의존 (단방향)

**예시**:
```dart
// lib/presentation/pages/home_page.dart
final memoListProvider = FutureProvider((ref) async {
  final repository = ref.watch(memoRepositoryProvider);
  return repository.getMemos();
});
```

### #layer/domain - 도메인 계층
**위치**: `lib/domain/`

**책임**:
- 비즈니스 로직
- 엔티티 정의 (Domain objects)
- Use Cases (기능)
- 저장소 인터페이스 정의

**의존성**: 다른 계층에 의존하지 않음 (독립적)

**예시**:
```dart
// lib/domain/usecases/create_memo.dart
class CreateMemo {
  final MemoRepository repository;
  
  Future<void> call(Memo memo) async {
    return repository.saveMemo(memo);
  }
}
```

### #layer/data - 데이터 계층
**위치**: `lib/data/`

**책임**:
- 데이터 소스 관리 (로컬, 원격)
- 모델 정의 및 직렬화
- 저장소 구현
- 캐시 관리

**의존성**: Domain의 인터페이스 구현

**예시**:
```dart
// lib/data/repositories/memo_repository_impl.dart
class MemoRepositoryImpl implements MemoRepository {
  final LocalDataSource localSource;
  final RemoteDataSource remoteSource;
  
  Future<void> saveMemo(Memo memo) async {
    await localSource.saveMemo(memo);
    await remoteSource.syncMemo(memo);
  }
}
```

### #layer/core - 핵심 계층
**위치**: `lib/core/`

**책임**:
- 상수 정의
- 유틸리티 함수
- 확장 메서드
- 디자인 토큰/테마

---

## Feature-Based 모듈 구성

각 주요 기능은 자체 Feature 디렉토리를 가집니다:

### Feature 1: Memo Feature #feature/memo
텍스트 메모의 생성, 읽기, 업데이트, 삭제

```
features/memo/
├── data/
│   ├── datasources/memo_local_datasource.dart
│   ├── models/memo_model.dart
│   └── repositories/memo_repository_impl.dart
├── domain/
│   ├── entities/memo.dart
│   ├── repositories/memo_repository.dart
│   └── usecases/
│       ├── create_memo.dart
│       ├── get_memo.dart
│       └── delete_memo.dart
└── presentation/
    ├── pages/memo_list_page.dart
    ├── widgets/memo_card.dart
    └── state/memo_provider.dart
```

### Feature 2: Voice Feature #feature/voice
음성 녹음 및 STT 처리

**관련**: [[voice-processing]]

### Feature 3: Tag Feature #feature/tags
태그 관리 및 분류

### Feature 4: Search Feature #feature/search
메모 검색 기능

### Feature 5: Sync Feature #feature/sync
클라우드 동기화

**관련**: [[sync-strategy]]

### Feature 6: Auth Feature #feature/auth
인증 (회원가입/로그인)

---

## 주요 파일 위치 참조

| 파일/디렉토리 | 위치 | 목적 |
|-------------|------|------|
| **앱 진입점** | `lib/main.dart` | Flutter 앱 시작, MaterialApp 설정 |
| **디자인 토큰** | `lib/core/theme/` | 색상, 폰트, 전체 디자인 시스템 |
| **로컬 DB** | `lib/data/datasources/local/` | Hive/Isar 로컬 저장소 |
| **API 클라이언트** | `lib/data/datasources/remote/` | 백엔드 HTTP 통신 |
| **비즈니스 로직** | `lib/domain/usecases/` | 메모 생성, 검색, 동기화 등 |
| **화면** | `lib/presentation/pages/` | 홈, 메모 상세, 검색 페이지 |
| **상태관리** | `lib/presentation/state/` | Riverpod Providers |
| **재사용 위젯** | `lib/presentation/widgets/` | 메모 카드, 태그 칩, 음성 녹음 버튼 |
| **다국어** | `assets/translations/` | 한국어, 영어 JSON |
| **의존성** | `pubspec.yaml` | 모든 Pub.dev 패키지 |
| **린트 설정** | `analysis_options.yaml` | Dart 코드 린트 규칙 |

---

## 아키텍처 패턴

### Clean Architecture 원칙
이 프로젝트는 **Clean Architecture** 패턴을 따릅니다:

```
Presentation Layer (Pages, Widgets, State)
        ↓ depends on
Domain Layer (Entities, UseCases, Interfaces)
        ↑ depends on
Data Layer (Repositories, Models, DataSources)
```

**의존성 방향**: Presentation → Domain ← Data (단방향)

**이점**:
- 테스트 가능성 증대
- 계층 간 독립성
- 비즈니스 로직 독립적 개발
- 데이터 소스 교체 용이

### Repository 패턴
데이터 소스를 추상화하여 로컬/원격 구분 없음

```dart
// Domain: 인터페이스
abstract class MemoRepository {
  Future<List<Memo>> getMemos();
}

// Data: 구현
class MemoRepositoryImpl implements MemoRepository {
  // 로컬과 원격 모두 처리
}

// Presentation: 사용
final memos = repository.getMemos(); // 동기화 투명
```

---

## 모듈 간 의존성 그래프

```
presentation/pages
    ↓ uses
presentation/state (Riverpod)
    ↓ uses
domain/usecases
    ↓ uses
data/repositories
    ↓ uses
data/datasources (local, remote)
    ↓ uses
core/utils, constants, theme
```

---

## 개발 워크플로우

### 1. 새로운 기능 추가
```
1. domain/usecases/new_feature.dart 작성 (비즈니스 로직)
2. data/repositories/impl 추가 (데이터 처리)
3. presentation/pages + widgets 추가 (UI)
4. presentation/state (Riverpod) 추가 (상태)
5. test/ 추가 (테스트)
```

### 2. 테스트 추가
```
test/unit/usecases/     # UseCase 로직
test/widget/            # Widget 렌더링
integration_test/       # 엔드-투-엔드
```

---

## 참고 문서

- [[product]] - 기능 정의
- [[tech]] - 기술 스택
- [[voice-processing]] - 음성 처리 아키텍처
- [[database-options]] - 로컬/원격 DB 선택
