# memo-everywhere

크로스 플랫폼 Flutter 메모 앱. iOS 11.0 이상, Android SDK 21 이상에서 완벽하게 동작하는 오프라인 우선(offline-first) 텍스트 메모 관리 애플리케이션입니다.

## 개요

**memo-everywhere**는 사용자가 언제 어디서나 메모를 작성, 조회, 수정, 삭제할 수 있는 간단하고 빠른 메모 앱입니다. 모든 데이터는 Hive 로컬 저장소에 저장되어 네트워크 연결 없이도 완벽하게 동작합니다.

### 주요 특징

- **CRUD 기능**: 메모 생성, 조회, 수정, 삭제
- **오프라인 지원**: Hive 로컬 저장소 - 항상 데이터에 접근 가능
- **크로스 플랫폼**: iOS와 Android에서 동일하게 동작
- **깔끔한 UI**: 직관적인 인터페이스와 빠른 성능
- **자동 정렬**: 최근 수정 순서로 자동 정렬

## 기술 스택

### 핵심 프레임워크
- **Flutter**: 3.22 LTS 이상
- **Dart**: 3.2.0 이상

### 상태 관리 & 라우팅
- **Riverpod**: 반응형 상태 관리 (`@riverpod` 코드 생성)
- **go_router**: 타입 안전 라우팅

### 데이터 저장소
- **Hive**: 로컬 key-value 저장소
- **hive_flutter**: Flutter 플랫폼 통합

### 아키텍처
- **Clean Architecture**: Presentation → Domain ← Data 계층 분리
- Domain 계층은 외부 프레임워크에 의존하지 않음
- 테스트 가능성과 유지보수성 최우선

### 개발 도구
- **build_runner**: 코드 생성 (Hive TypeAdapter, Riverpod)
- **flutter_lints**: Lint 규칙

## 실행 방법

### 사전 요구사항
- Flutter SDK 3.22 LTS 이상
- Dart SDK 3.2.0 이상
- iOS 개발 환경 (macOS 필수)
- Android Studio 또는 Android NDK (Android 개발)

### 의존성 설치
```bash
flutter pub get
```

### 코드 생성 (Hive + Riverpod)
```bash
dart run build_runner build
```

또는 개발 중 자동으로 감시:
```bash
dart run build_runner watch --delete-conflicting-outputs
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
│       └── delete_memo.dart
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

**SPEC-MEMO-001: 텍스트 메모 CRUD MVP**

텍스트 메모의 기본 CRUD 기능을 정의합니다. 상세 내용은 `.moai/specs/SPEC-MEMO-001/spec.md`를 참조하세요.

- 요구사항: 10개 (EARS 형식)
- 구현 파일: 17개
- 테스트: 9개 + 코드 생성 파일

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

**최근 업데이트**: 2026-06-25 (SPEC-MEMO-001 완료)
