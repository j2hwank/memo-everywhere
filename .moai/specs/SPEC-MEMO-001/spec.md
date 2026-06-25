---
id: SPEC-MEMO-001
version: "1.0.0"
status: completed
created_at: "2026-06-25"
updated: "2026-06-25"
author: Kwon
priority: high
issue_number: 0
labels: ["flutter", "crud", "hive", "mvp", "offline"]
---

# SPEC-MEMO-001: 텍스트 메모 CRUD MVP

## HISTORY

- v1.0.0 — 2026-06-25 — initial draft

## Overview

이 SPEC은 memo-everywhere의 Phase 1 MVP 중 첫 번째이자 기반(foundation) 기능인 텍스트 메모 CRUD를 정의한다. 사용자는 메모를 생성·조회·수정·삭제할 수 있으며, 모든 데이터는 Hive 로컬 저장소에 보관되어 네트워크 없이도 완전하게 동작한다. 대상 플랫폼은 iOS(11.0+)와 Android(SDK 21+)이며, 두 플랫폼에서 동일하게 동작한다.

본 기능은 Clean Architecture로 구축되어 이후 모든 기능(음성·태그·검색·동기화)이 확장될 토대를 마련한다. 의존성 방향은 Presentation → Domain ← Data 단방향을 엄격히 따르며, Domain 계층(엔티티, 저장소 계약, UseCase)은 어떤 외부 프레임워크에도 의존하지 않는다. 개발 방식은 TDD(Red-Green-Refactor)를 적용한다.

## EARS Requirements

### REQ-MEMO-001: 메모 생성
WHEN the user taps the FAB/create button on HomePage, the system SHALL navigate to MemoEditorPage in create mode.

### REQ-MEMO-002: 메모 저장
WHEN the user taps Save on MemoEditorPage with non-empty content, the system SHALL persist the Memo to Hive local storage and navigate back to HomePage.

### REQ-MEMO-003: 입력 검증
IF the content field is empty, WHEN the user taps Save, THEN the system SHALL display a validation error and SHALL NOT save.

### REQ-MEMO-004: 메모 목록 표시
WHEN HomePage is loaded, the system SHALL display all memos from Hive in reverse chronological order (updatedAt DESC).

### REQ-MEMO-005: 빈 상태
IF no memos exist, WHEN HomePage is loaded, THEN the system SHALL display an empty state message.

### REQ-MEMO-006: 메모 편집
WHEN the user taps a MemoCard on HomePage, the system SHALL navigate to MemoEditorPage in edit mode with the existing memo content pre-filled.

### REQ-MEMO-007: 메모 수정 저장
WHEN the user taps Save on MemoEditorPage in edit mode, the system SHALL update the existing Memo in Hive with new content and a new updatedAt timestamp.

### REQ-MEMO-008: 메모 삭제
WHEN the user long-presses a MemoCard or taps the delete icon, the system SHALL show a confirmation dialog; WHEN confirmed, the system SHALL delete the memo from Hive and remove it from the list.

### REQ-MEMO-009: 오프라인 동작
WHERE network is unavailable, the system SHALL continue to function fully using Hive local data with no degradation.

### REQ-MEMO-010: 플랫폼 호환성
WHERE running on iOS 11.0+ or Android SDK 21+, the system SHALL behave identically.

## Technical Approach

### Clean Architecture 계층 구조

의존성 방향은 Presentation → Domain ← Data 단방향을 엄격히 따른다. Domain 계층은 어떤 외부 프레임워크에도 의존하지 않는다.

- **Core 계층**: 공유 상수(`memosBoxName = 'memos'`, MemoModel `typeId = 0`)와 라우팅 설정을 보관한다.
- **Domain 계층**: 불변(immutable) `Memo` 값 객체, 추상 `MemoRepository` 인터페이스(모든 UseCase가 의존하는 계약), 4개 UseCase(Create/Get/Update/Delete)로 구성된다. 외부 의존성 없음.
- **Data 계층**: Hive 어댑터를 가진 `MemoModel`, `MemoLocalDataSource`(Hive 박스 CRUD), `MemoRepositoryImpl`(LocalDataSource만 사용, 엔티티 ↔ 모델 변환)로 구성된다. 네트워크 호출 없음.
- **Presentation 계층**: Riverpod providers, `MemoCard` 위젯, `HomePage`, `MemoEditorPage`로 구성된다.

### Hive 로컬 저장소 설정

- `Hive.initFlutter()` → `Hive.registerAdapter(MemoModelAdapter())` → `Hive.openBox<MemoModel>('memos')`를 `runApp()` 이전에 await로 완료한다.
- `MemoModel`은 `@HiveType(typeId: 0)`을 사용하며 각 필드에 `@HiveField` 애너테이션을 붙인다. typeId 0은 예약되어 변경 불가(변경 시 기존 박스 손상).
- 향후 모델은 typeId 1, 2, 3...을 사용한다.

### Riverpod 코드 생성 (codegen)

- `@riverpod` 애너테이션 + build_runner codegen 사용.
- `memoLocalDataSourceProvider`, `memoRepositoryProvider`, `memosProvider`(AsyncNotifier — 목록 로드/정렬), `memoNotifierProvider`(생성/수정/삭제 액션)를 노출한다.
- Hive와 Riverpod 코드 생성은 단일 `dart run build_runner watch --delete-conflicting-outputs` 명령으로 모두 처리한다.

### go_router 내비게이션

- 라우트는 `GoRoute`로 정의: `/` (HomePage), `/memo/new` (MemoEditorPage 생성 모드), `/memo/:id` (MemoEditorPage 편집 모드).
- 내비게이션은 `context.go()`를 사용한다.
- GoRouter는 routerProvider 패턴으로 Riverpod에서 노출하여 `ref.watch` 통합 문제를 방지한다.

### 기술 제약

- Flutter SDK: 3.22 LTS 이상 / Dart SDK: `>=3.2.0 <4.0.0`
- UUID 생성: uuid 패키지 v4 알고리즘
- Timestamp: createdAt/updatedAt에 `DateTime.now().toUtc()` 사용
- iOS 최소 배포 타겟: 11.0 (pubspec + Podfile) / Android 최소 SDK: 21 (build.gradle)
- 이 SPEC에서는 네트워크 호출 없음 — `MemoRepositoryImpl`은 LocalDataSource만 사용

자세한 File Plan은 `plan.md`를 참조한다.

## Files to Modify/Create

### Flutter Project Root
- `pubspec.yaml` — 의존성 정의 (hive, hive_flutter, flutter_riverpod, riverpod_annotation, go_router, uuid, intl + dev: hive_generator, build_runner, riverpod_generator, flutter_lints)

### Core Layer
- `lib/core/constants/app_constants.dart` — 공유 상수 (memosBoxName, typeId)
- `lib/core/router/app_router.dart` — GoRouter 설정 및 라우트 경로 상수

### Domain Layer
- `lib/domain/entities/memo.dart` — Memo 불변 값 객체
- `lib/domain/repositories/memo_repository.dart` — 추상 MemoRepository 인터페이스
- `lib/domain/usecases/create_memo.dart` — CreateMemo UseCase
- `lib/domain/usecases/get_memos.dart` — GetMemos UseCase
- `lib/domain/usecases/update_memo.dart` — UpdateMemo UseCase
- `lib/domain/usecases/delete_memo.dart` — DeleteMemo UseCase

### Data Layer
- `lib/data/models/memo_model.dart` — MemoModel + Hive 어댑터
- `lib/data/datasources/local/memo_local_datasource.dart` — MemoLocalDataSource 인터페이스 + Impl
- `lib/data/repositories/memo_repository_impl.dart` — MemoRepositoryImpl

### Presentation Layer
- `lib/presentation/state/memo_provider.dart` — Riverpod providers
- `lib/presentation/widgets/memo_card.dart` — MemoCard 위젯
- `lib/presentation/pages/home_page.dart` — HomePage
- `lib/presentation/pages/memo_editor_page.dart` — MemoEditorPage

### Entry
- `lib/main.dart` — 앱 진입점 (Hive 초기화 + ProviderScope + MaterialApp.router)

### Tests
- `test/unit/domain/entities/memo_test.dart` — Memo copyWith, 동등성(equality) 검증
- `test/unit/domain/usecases/create_memo_test.dart` — id/타임스탬프 생성, 저장소 호출 검증
- `test/unit/domain/usecases/get_memos_test.dart` — updatedAt DESC 정렬, 빈 목록 처리
- `test/unit/domain/usecases/update_memo_test.dart` — updatedAt 갱신, createdAt 보존
- `test/unit/domain/usecases/delete_memo_test.dart` — 저장소 삭제 호출 검증
- `test/unit/data/repositories/memo_repository_impl_test.dart` — CRUD + 엔티티/모델 변환 검증
- `test/widget/memo_card_test.dart` — 제목/미리보기 렌더링, onTap/onLongPress 콜백
- `test/widget/home_page_test.dart` — 빈 상태/메모 목록 상태 렌더링
- `test/widget/memo_editor_page_test.dart` — 내용 검증(빈 내용 차단), 저장 흐름, 생성/편집 모드

총 17개 구현 파일 + 9개 테스트 파일.

## Exclusions (What NOT to Build)

본 SPEC은 Phase 1 MVP의 기반 CRUD에만 집중하며, 아래 항목은 명시적으로 범위에서 제외한다:

1. **음성 입력 / STT(Speech-to-Text)** — 음성 녹음 및 음성→텍스트 변환 기능은 제외한다.
2. **태그(Tags) / 분류** — 메모 태깅, 카테고리, 폴더 기능은 제외한다.
3. **클라우드 동기화(Cloud Sync)** — 원격 서버 동기화, 백엔드 API, 다중 기기 동기화는 제외한다(LocalDataSource만 사용).
4. **검색(Search)** — 메모 내용 검색, 필터링 기능은 제외한다.
5. **인증(Authentication)** — 로그인, 회원가입, 계정 관리는 제외한다.
6. **데스크톱/웹 플랫폼** — macOS, Windows, Linux, Web 지원은 제외한다(iOS, Android만 대상).
7. **리치 텍스트(Rich Text)** — 서식 있는 텍스트, 마크다운 렌더링, 이미지/첨부 파일은 제외한다(평문 텍스트만).

## MX Tag Strategy

그린필드 프로젝트이므로 MX 태그는 구현 단계에서 추가한다:

- `MemoRepository` 인터페이스: `@MX:ANCHOR` (높은 fan_in — 모든 UseCase가 의존)
- `MemoRepositoryImpl.getAll()`: `@MX:NOTE` (정렬 로직 — updatedAt DESC)
- `main.dart` Hive 초기화: `@MX:ANCHOR` (부트스트랩 불변식 — 모든 Hive 접근 이전에 실행되어야 함)
- `MemoModel` typeId: `@MX:ANCHOR` (반드시 0 유지 — 변경 시 기존 Hive 박스 손상)

## TDD Task Sequence

RED-GREEN-REFACTOR 사이클을 따른다.

### RED Phase (실패하는 테스트 먼저 작성)
1. 도메인 엔티티 테스트 작성 (Memo copyWith, 동등성)
2. mock MemoRepository로 UseCase 단위 테스트 작성
3. mock LocalDataSource로 Repository impl 테스트 작성
4. MemoCard, HomePage(빈/채워진 상태) 위젯 테스트 작성

### GREEN Phase (최소 구현)
5. Memo 엔티티 구현
6. UseCases 구현
7. MemoModel + TypeAdapter 구현 (build_runner 실행)
8. MemoLocalDataSource (Hive) 구현
9. MemoRepositoryImpl 구현
10. Riverpod providers 구현 (build_runner 실행)
11. MemoCard 위젯 구현
12. HomePage 구현
13. MemoEditorPage 구현
14. go_router + main.dart 구성

### REFACTOR Phase
15. 상수 추출 (박스 이름, 라우트 경로)
16. 에러 핸들링 추가 (HiveError → AppException)
17. MemoCard 렌더링 최적화 (const 생성자)

---

## 구현 완료 요약

**완료일**: 2026-06-25
**구현 방법론**: TDD (RED-GREEN-REFACTOR)
**커밋**: cf43734 (feat), 73852c1 (chore)

### 구현된 파일 (29개)
- Clean Architecture 3계층: domain, data, presentation
- 핵심 엔티티: `Memo` (불변 값 객체)
- 저장소: Hive 로컬 DB (typeId=0)
- 상태 관리: Riverpod `@riverpod` 코드 생성 (Memos + MemoNotifier)
- 라우팅: go_router (홈 → 신규 메모 → 편집)
- 테스트: 단위 테스트 (domain/data), 위젯 테스트 (presentation) 29개

### 품질 게이트 결과
- `flutter analyze`: 0 errors, 0 warnings, 3 infos (generated 파일 deprecated API)
- `flutter test`: 전체 통과
