# Plan: SPEC-MEMO-001 텍스트 메모 CRUD

## SPEC Overview
- SPEC ID: SPEC-MEMO-001
- Title: 텍스트 메모 CRUD MVP
- Priority: High
- Platforms: iOS, Android
- Development Mode: TDD (Red-Green-Refactor)

이 SPEC은 memo-everywhere Phase 1 MVP의 첫 번째이자 기반 기능이다. Memo 엔티티, 도메인 계층, Hive 로컬 저장소를 Clean Architecture로 구축하여 이후 모든 기능(음성·태그·검색·동기화)의 토대를 마련한다. 의존성 방향은 Presentation → Domain ← Data 단방향을 엄격히 따른다.

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

## File Plan

### New Files to Create

#### Flutter Project Root
- `pubspec.yaml` — 의존성 정의. dependencies: `hive ^2.2.3`, `hive_flutter ^1.1.0`, `flutter_riverpod ^2.4.9`, `riverpod_annotation ^2.3.3`, `go_router ^13.2.0`, `uuid ^4.3.3`, `intl ^0.18.1`. dev_dependencies: `hive_generator ^2.0.1`, `build_runner ^2.4.8`, `riverpod_generator ^2.3.9`, `flutter_lints ^3.0.0`. environment.sdk: `>=3.2.0 <4.0.0`.

#### Core Layer
- `lib/core/constants/app_constants.dart` — 공유 상수: Hive 박스 이름 `memosBoxName = 'memos'`, MemoModel `typeId = 0`. 라우트 경로 상수는 라우터 파일에 둔다.

#### Domain Layer
- `lib/domain/entities/memo.dart` — Memo 값 객체(불변, immutable). 필드: `id`, `title`(nullable), `content`, `createdAt`, `updatedAt`. `copyWith` 및 동등성(equality) 제공. 어떤 외부 계층에도 의존하지 않음.
- `lib/domain/repositories/memo_repository.dart` — 추상 `MemoRepository` 인터페이스. 메서드: `create`, `getAll`, `update`, `delete`. 모든 UseCase가 의존하는 계약(contract).
- `lib/domain/usecases/create_memo.dart` — `CreateMemo` UseCase. input: `CreateMemoParams(title?, content)`, output: `Memo`. id/createdAt/updatedAt 생성을 담당.
- `lib/domain/usecases/get_memos.dart` — `GetMemos` UseCase. output: `List<Memo>` (updatedAt DESC 정렬).
- `lib/domain/usecases/update_memo.dart` — `UpdateMemo` UseCase. input: `UpdateMemoParams(id, title?, content)`. updatedAt 갱신을 담당.
- `lib/domain/usecases/delete_memo.dart` — `DeleteMemo` UseCase. input: `String id`.

#### Data Layer
- `lib/data/models/memo_model.dart` — `MemoModel` (Memo 매핑). Hive `@HiveType(typeId: 0)` 어댑터, 각 필드 `@HiveField` 애너테이션. `fromMemo` 팩토리, `toMemo` 메서드. build_runner가 `memo_model.g.dart` 어댑터 생성.
- `lib/data/datasources/local/memo_local_datasource.dart` — 추상 인터페이스 + `MemoLocalDataSourceImpl`. `Hive.box<MemoModel>('memos')`를 사용하여 CRUD 수행.
- `lib/data/repositories/memo_repository_impl.dart` — `MemoRepositoryImpl implements MemoRepository`. LocalDataSource만 사용(네트워크 없음). 엔티티 ↔ 모델 변환 담당.

#### Presentation Layer
- `lib/presentation/state/memo_provider.dart` — Riverpod providers: `memoLocalDataSourceProvider`, `memoRepositoryProvider`, `memosProvider`(AsyncNotifier — 목록 로드/정렬), `memoNotifierProvider`(생성/수정/삭제 액션). `@riverpod` 애너테이션 + codegen 사용.
- `lib/presentation/widgets/memo_card.dart` — `MemoCard` 위젯. 제목(없으면 content 미리보기) + updatedAt 상대 시간 표시. `onTap` → 편집 화면, `onLongPress` → 삭제 확인 다이얼로그.
- `lib/presentation/pages/home_page.dart` — `HomePage` (ConsumerWidget). 새 메모용 FAB, MemoCard ListView 또는 EmptyState 표시.
- `lib/presentation/pages/memo_editor_page.dart` — `MemoEditorPage` (ConsumerStatefulWidget). 제목 TextField(선택), 내용 TextField(필수, multiline), Save 버튼, 검증, 생성/편집 모드 지원.

#### Routing & Entry
- `lib/core/router/app_router.dart` — GoRouter 설정. 라우트: `/` (HomePage), `/memo/new` (MemoEditorPage 생성 모드), `/memo/:id` (MemoEditorPage 편집 모드). 라우트 경로 문자열 상수 포함.
- `lib/main.dart` — Flutter 앱 진입점. `Hive.initFlutter()`, `Hive.registerAdapter(MemoModelAdapter())`, `Hive.openBox<MemoModel>('memos')`를 `runApp` 이전에 await. `ProviderScope` + `MaterialApp.router`.

#### Tests
- `test/unit/domain/entities/memo_test.dart` — Memo copyWith, 동등성(equality) 검증.
- `test/unit/domain/usecases/create_memo_test.dart` — CreateMemo: id/타임스탬프 생성, 저장소 호출 검증.
- `test/unit/domain/usecases/get_memos_test.dart` — GetMemos: updatedAt DESC 정렬, 빈 목록 처리.
- `test/unit/domain/usecases/update_memo_test.dart` — UpdateMemo: updatedAt 갱신, 기존 createdAt 보존.
- `test/unit/domain/usecases/delete_memo_test.dart` — DeleteMemo: 저장소 삭제 호출 검증.
- `test/unit/data/repositories/memo_repository_impl_test.dart` — mock LocalDataSource로 CRUD + 엔티티/모델 변환 검증.
- `test/widget/memo_card_test.dart` — 제목/미리보기 렌더링, onTap/onLongPress 콜백 검증.
- `test/widget/home_page_test.dart` — 빈 상태 / 메모 목록 상태 렌더링 검증.
- `test/widget/memo_editor_page_test.dart` — 빈 내용 검증(저장 차단), Save 흐름, 생성/편집 모드 전환 검증.

## Technical Constraints

- Flutter SDK: 3.22 LTS 이상
- Dart SDK: `>=3.2.0 <4.0.0`
- Hive typeId: 0을 MemoModel에 예약 (향후 모델은 1, 2, 3... 사용)
- Box name: `'memos'` (공유 상수 파일의 문자열 상수)
- UUID 생성: uuid 패키지 v4 알고리즘
- Timestamp: createdAt/updatedAt에 `DateTime.now().toUtc()` 사용
- Riverpod: `@riverpod` 애너테이션 + build_runner codegen
- go_router: 라우트는 `GoRoute`로 정의, 내비게이션은 `context.go()` 사용
- 이 SPEC에서는 네트워크 호출 없음 — MemoRepositoryImpl은 LocalDataSource만 사용
- iOS 최소 배포 타겟: 11.0 (pubspec + Podfile)
- Android 최소 SDK: 21 (build.gradle)

## Risk Analysis

1. **Hive TypeAdapter codegen**: `@HiveType` 애너테이션 추가 후 build_runner 실행 필요. 위험: 개발자가 `dart run build_runner build` 실행을 누락. 완화: 본 plan과 워크플로우에 명시.
2. **Riverpod 코드 생성**: 동일하게 build_runner 필요. 완화: 단일 `dart run build_runner watch --delete-conflicting-outputs` 명령으로 Hive와 Riverpod 코드젠을 모두 커버.
3. **Hive 박스 초기화 순서**: `Hive.initFlutter()` + `Hive.registerAdapter()` + `openBox`가 `runApp()` 이전에 완료되어야 함. 완화: `async main()`에서 await 처리.
4. **go_router + Riverpod 통합**: GoRouter 내부에서 `ref.watch` 사용 시 문제 가능. 완화: routerProvider 패턴으로 라우터를 Riverpod에서 노출.
5. **테스트 격리**: Hive 박스는 테스트 간 닫기/삭제 필요. 완화: 각 테스트 파일에서 setUp/tearDown 사용, UseCase/Repository 테스트는 mock LocalDataSource로 Hive 의존성 차단.

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
4. MemoCard, HomePage(빈/채워진 상태), MemoEditorPage(검증·저장·모드전환) 위젯 테스트 작성

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
