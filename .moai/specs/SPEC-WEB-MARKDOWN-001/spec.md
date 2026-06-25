---
spec_id: SPEC-WEB-MARKDOWN-001
title: "Flutter Web 지원 (마크다운 렌더링 철회)"
status: implemented
version: 1.0.2
created: 2026-06-25
updated: 2026-06-25
author: manager-spec
priority: high
methodology: tdd
dependencies: [SPEC-MEMO-001, SPEC-BACKEND-001]
---

# SPEC-WEB-MARKDOWN-001: Flutter Web 지원 + 마크다운 렌더링 미리보기

## HISTORY

- v1.0.2 — 2026-06-25 — 마크다운 렌더링 부분 철회(읽기 모드 미리보기 제거, 순수 텍스트 편집 복원). Flutter Web 지원은 유지. 사유: 옵시디안 스타일 인라인 실시간 렌더링 목표였으나 Flutter 구현 경로 부재로 범위 제외.
- v1.0.1 — 2026-06-25 — implementation complete, all ACs pass
- v1.0.0 — 2026-06-25 — initial draft

## 메타데이터
- **상태**: draft
- **버전**: 1.0.0
- **생성일**: 2026-06-25
- **의존성**: SPEC-MEMO-001 (메모 상세/작성 화면 재사용), SPEC-BACKEND-001 (REQ-WM-009 웹 저장소는 백엔드 사용)

## 개요

**Flutter Web 플랫폼 지원**과 **읽기 모드 마크다운 렌더링 미리보기**를 정의한다. `flutter build web`으로 배포 가능한 웹 아티팩트를 생성하고, 메모를 읽기 모드로 볼 때 `flutter_markdown`으로 마크다운 문법을 시각적으로 렌더링한다. **입력(편집)은 순수 텍스트를 유지**하며 렌더링은 읽기 전용이다 — 이것은 마크다운 에디터가 아니다. 웹에서는 로컬 Hive 대신 FastAPI 백엔드를 메모 저장소로 사용하고, 오디오/STT는 웹 전용 구현(Web Speech API, WAV)을 런타임에 선택한다.

## 배경 및 동기

`product.md`의 핵심 기능 6번(크로스플랫폼 지원, `#feature/platform`)과 로드맵 Phase 2(Web 지원)를 충족한다. 웹은 새로 추가되는 주요 플랫폼 타겟으로, 사용 사례 3(멀티디바이스 접근)에서 "Mac 브라우저"로 메모를 읽는 경로를 가능하게 한다.

마크다운 렌더링은 `product.md` Non-Goal "텍스트 형식 지정(Rich Text)"과의 경계를 신중히 지킨다. Non-Goal은 **마크다운/WYSIWYG 에디터 미지원**을 명시하므로, 본 SPEC은 **편집 기능을 추가하지 않고** 읽기 모드에서의 시각적 렌더링만 추가한다. 저장되는 데이터는 여전히 순수 텍스트이며 동기화 복잡도는 증가하지 않는다.

## 요구사항 (EARS 형식)

### 기능 요구사항

#### REQ-WM-001: 웹 빌드 산출물
The system SHALL support `flutter build web`, producing a deployable web artifact.

#### REQ-WM-002: 읽기 모드 마크다운 렌더링
WHEN a memo is viewed in read mode, the system SHALL render its markdown syntax visually using the `flutter_markdown` package.

#### REQ-WM-003: 편집 모드 순수 텍스트
WHEN a memo is being edited, the system SHALL display a plain-text input (markdown rendering is READ-only and SHALL NOT apply to the editor).

#### REQ-WM-004: 지원 마크다운 문법
The system SHALL render the following markdown constructs: headers (`#`/`##`/`###`), bold (`**text**`), italic (`*text*`), unordered lists (`- item`), fenced code blocks (` ``` `), blockquotes (`>`), and links (`[text](url)`).

#### REQ-WM-005: 웹 STT (Web Speech API)
WHERE the platform is Web, the system SHALL perform STT via the Web Speech API through the `speech_to_text` package (no native plugin).

#### REQ-WM-006: 웹 오디오 코덱 (WAV)
WHERE the platform is Web, the system SHALL use the WAV audio codec for recording.

#### REQ-WM-007: 런타임 플랫폼 감지
The system SHALL detect the platform at runtime and select the appropriate audio/STT implementation.

#### REQ-WM-008: 웹 플랫폼 설정 생성
The system SHALL run `flutter create --platforms=web .` to add the `web/` directory configuration.

#### REQ-WM-009: 웹 메모 저장소 (백엔드)
WHEN the user is on the Web platform, the system SHALL connect to the FastAPI backend for memo storage and SHALL NOT use local Hive on web.

### 비기능 요구사항

- **성능**: 마크다운 렌더링은 메모 상세 진입 시 즉각적으로 표시되어야 한다(체감 지연 없음). 웹 앱 시작은 `product.md` 지표(< 1초, 초기 로드 제외)를 지향한다.
- **호환성**: 최신 Chrome/Safari/Firefox/Edge에서 동작한다. Web Speech API 미지원 브라우저에서는 STT를 비활성화하고 텍스트 입력으로 우회한다.
- **데이터 일관성**: 마크다운 렌더링은 저장 데이터를 변형하지 않는다(표시 전용). 저장값은 항상 순수 텍스트.
- **보안**: 렌더링 시 링크/HTML 인젝션을 방지한다(`flutter_markdown` 기본 sanitization 사용, raw HTML 비허용).
- **플랫폼 격리**: 웹에서 `dart:io`/네이티브 플러그인 의존 코드가 컴파일되지 않도록 조건부 임포트 또는 런타임 분기를 적용한다.

## 구현 범위

### 포함 (In Scope)
- `flutter create --platforms=web .`로 `web/` 디렉터리 추가 및 `flutter build web` 동작
- `flutter_markdown`을 이용한 읽기 모드 마크다운 렌더링
- 메모 상세 화면의 읽기/편집 모드 토글 (편집은 순수 텍스트 유지)
- 지원 문법: 헤더/볼드/이탤릭/리스트/코드블록/인용/링크
- 런타임 플랫폼 감지 유틸(`platform_utils.dart`)
- 웹 STT(Web Speech API) 및 웹 오디오(WAV) 경로 선택
- 웹에서 백엔드(SPEC-BACKEND-001) 저장소 사용(로컬 Hive 미사용)

### 제외 (Out of Scope)
- **마크다운/WYSIWYG 에디터** — `product.md` Non-Goal(Rich Text 미지원). 본 SPEC은 읽기 전용 렌더링만 추가하며, 편집 화면은 순수 텍스트 입력을 유지한다. 마크다운 작성 보조(툴바, 자동완성, 라이브 프리뷰 동시편집)는 제외한다.
- **확장 마크다운 문법** — 표(table), 각주, 체크리스트, 이미지 임베드(`![]`), 수식(LaTeX), syntax highlighting은 제외한다(REQ-WM-004 목록만).
- **이미지/파일 렌더링** — `product.md` Non-Goal(첨부 미지원). 이미지 마크다운은 렌더링 대상에서 제외한다.
- **데스크톱(Windows/Linux/macOS) 플랫폼 추가** — 본 SPEC은 Web 플랫폼 추가에 한정한다(데스크톱은 별도 SPEC).
- **PWA/오프라인 캐시/서비스워커** — 웹 오프라인 동작 및 설치형 PWA 설정은 제외한다(웹은 백엔드 온라인 저장소 사용).
- **웹 배포/호스팅 파이프라인** — 빌드 산출물 생성까지만 포함하며 배포 인프라는 DevOps 범위로 분리한다.

## 인수 조건 (Acceptance Criteria)

| # | 조건 | 검증 방법 |
|---|------|---------|
| AC-1 | `flutter build web`이 에러 없이 산출물을 생성 | CI/로컬: `flutter build web` 성공 종료 코드 |
| AC-2 | 읽기 모드에서 마크다운이 시각적으로 렌더링됨 | 위젯 테스트: `# 제목` 입력 → `flutter_markdown` 헤더 위젯 렌더 검증 |
| AC-3 | 편집 모드는 순수 텍스트 입력을 표시(렌더링 없음) | 위젯 테스트: 편집 모드 → `TextField`에 raw 마크다운 문자열 표시 |
| AC-4 | 헤더/볼드/이탤릭/리스트/코드/인용/링크가 렌더링됨 | 위젯 테스트: 각 문법별 대응 위젯/스타일 렌더 검증 |
| AC-5 | 웹 플랫폼에서 Web Speech API 경로가 선택됨 | 단위 테스트: `kIsWeb == true` → 웹 STT 구현 선택 검증 |
| AC-6 | 웹 녹음이 WAV 코덱을 사용 | 단위 테스트: 웹 분기에서 `AudioEncoder.wav` 선택 검증 |
| AC-7 | 런타임 플랫폼 감지로 audio/STT 구현이 분기됨 | 단위 테스트: `platform_utils`가 웹/네이티브 분기 반환 |
| AC-8 | `web/` 디렉터리 설정이 존재 | 파일 검증: `web/index.html`, `web/manifest.json` 존재 |
| AC-9 | 웹에서 메모 저장이 백엔드를 사용(Hive 미사용) | 단위 테스트: `kIsWeb == true` → 원격 데이터소스 선택, 로컬 Hive 미호출 |

## 기술 설계 (Technical Design)

### 패키지 추가 (`pubspec.yaml`)

```yaml
dependencies:
  flutter_markdown: ^0.7.0
```

### 웹 플랫폼 추가 (REQ-WM-008)

```bash
flutter create --platforms=web .   # web/ 디렉터리(index.html, manifest.json 등) 생성
flutter build web                  # 배포 산출물 build/web/
```

### 런타임 플랫폼 감지 (REQ-WM-007) — 신규 `lib/core/utils/platform_utils.dart`

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformUtils {
  static bool get isWeb => kIsWeb;
  // SPEC-VOICE-001 코덱 분기와 공유 (단일 진실 공급원)
  static AudioEncoder get audioEncoder =>
      kIsWeb ? AudioEncoder.wav : _nativeEncoder();
  // 웹은 백엔드 저장소, 그 외는 로컬 Hive (REQ-WM-009)
  static bool get useRemoteStore => kIsWeb;
}
```

### 읽기/편집 모드 토글 (REQ-WM-002/003) — `lib/presentation/pages/memo_detail_page.dart` 수정

```dart
// 읽기 모드: 마크다운 렌더링 (표시 전용)
Widget _readView(Memo memo) => Markdown(
      data: memo.content,           // 저장값은 순수 텍스트, 표시만 렌더링
      selectable: true,
      // raw HTML 비허용 (보안) — 기본 sanitize 유지
    );

// 편집 모드: 순수 텍스트 입력 (렌더링 없음) — REQ-WM-003
Widget _editView(TextEditingController c) => TextField(
      controller: c,                // raw 마크다운 문자열 그대로 표시/편집
      maxLines: null,
    );
```

읽기 ↔ 편집 토글은 상세 화면 AppBar 액션(예: 연필/체크 아이콘)으로 전환한다. 저장 시점에 렌더링은 관여하지 않으며 `content`는 항상 순수 텍스트로 저장된다.

### 웹 STT/오디오 분기 (REQ-WM-005/006)

```dart
// SPEC-VOICE-001의 STT/녹음 경로에서 PlatformUtils로 분기
if (PlatformUtils.isWeb) {
  // speech_to_text의 Web Speech API 백엔드 사용 (네이티브 플러그인 없음)
  // record는 WAV 인코더로 녹음
}
```

### 웹 저장소 분기 (REQ-WM-009)

```dart
// 저장소 주입 시 플랫폼에 따라 데이터소스 선택
final dataSource = PlatformUtils.useRemoteStore
    ? memoRemoteDataSource   // SPEC-BACKEND-001
    : memoLocalDataSource;   // Hive (모바일/데스크톱)
```

### 수정/신규 파일

| 파일 | 구분 | 내용 |
|------|------|------|
| `web/` | 신규 | `flutter create --platforms=web .` 산출 |
| `lib/core/utils/platform_utils.dart` | 신규 | 런타임 플랫폼 감지 + audio/STT/store 분기 |
| `lib/presentation/pages/memo_detail_page.dart` | 수정 | 읽기/편집 모드 토글 + 마크다운 렌더링 |
| `pubspec.yaml` | 수정 | `flutter_markdown` 추가 |

## 구현 순서 (Implementation Order)

방법론: TDD (RED-GREEN-REFACTOR)

1. **Phase 1 — 웹 플랫폼 추가**: `flutter create --platforms=web .` 실행, `flutter build web` 성공 확인(REQ-WM-001, WM-008).
2. **Phase 2 — 플랫폼 감지 유틸**: `platform_utils.dart` 구현(런타임 분기)(REQ-WM-007). SPEC-VOICE-001 코덱 분기와 단일화.
3. **Phase 3 — 마크다운 렌더링**: `flutter_markdown` 통합, 읽기/편집 모드 토글, 지원 문법 렌더(REQ-WM-002, WM-003, WM-004).
4. **Phase 4 — 웹 STT/오디오 분기**: 웹에서 Web Speech API + WAV 선택(REQ-WM-005, WM-006). (SPEC-VOICE-001 연계)
5. **Phase 5 — 웹 저장소 분기**: 웹에서 백엔드 데이터소스 사용, Hive 미사용(REQ-WM-009). (SPEC-BACKEND-001 선행 필요)

> Phase 1~3은 백엔드 없이 독립 수행 가능하다(마크다운 렌더링은 로컬 메모로도 동작). Phase 4는 SPEC-VOICE-001, Phase 5는 SPEC-BACKEND-001에 의존한다.

## MX Tag Strategy

- `PlatformUtils.audioEncoder` / `useRemoteStore`: `@MX:ANCHOR` (플랫폼 분기 핵심 계약 — voice/storage가 의존)
- 마크다운 읽기 모드 렌더 분기: `@MX:NOTE` (읽기 전용 렌더링이며 저장값 비변형 의도 설명 — Non-Goal 경계)
- 웹 raw HTML 비허용 설정: `@MX:WARN` (`@MX:REASON`: 마크다운 렌더링 시 인젝션 방지)
- 조건부 임포트/`kIsWeb` 분기: `@MX:NOTE` (웹에서 `dart:io` 컴파일 회피 이유)

## 참고 문서
- `.moai/project/product.md` — 핵심 기능 6(크로스플랫폼), 로드맵 Phase 2(Web), Non-Goal(Rich Text 에디터 미지원)
- `.moai/project/tech.md` — Flutter Web 빌드, `flutter_markdown`, 플랫폼 분기 정책
- `.moai/specs/SPEC-MEMO-001/spec.md` — 메모 상세/작성 화면 (부모)
- `.moai/specs/SPEC-VOICE-001/spec.md` — 웹 STT/오디오 분기 연계 (REQ-WM-005/006)
- `.moai/specs/SPEC-BACKEND-001/spec.md` — 웹 저장소 백엔드 의존 (REQ-WM-009)
