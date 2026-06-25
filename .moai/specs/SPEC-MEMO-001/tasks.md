# Task Decomposition

SPEC: SPEC-MEMO-001 (텍스트 메모 CRUD MVP)
Development Mode: TDD (RED-GREEN-REFACTOR)
Architecture: Clean Architecture (Presentation → Domain ← Data, unidirectional)
Coverage Target: 85% (min 80% per commit)

Each task = one TDD cycle (RED → GREEN → REFACTOR) for one logical unit.
Tasks are ordered to respect the dependency graph: build depended-on layers first.

## Build Order Rationale

```
pubspec/constants → Memo entity → Repository interface + UseCases
  → MemoModel (+build_runner) → LocalDataSource → RepositoryImpl
  → Riverpod providers (+build_runner) → MemoCard → HomePage
  → MemoEditorPage + router + main.dart
```

Two mandatory `build_runner` checkpoints:
- After T-004 (MemoModel @HiveType) → generates `memo_model.g.dart` (HiveAdapter)
- After T-007 (@riverpod providers) → generates `memo_provider.g.dart`
- Command: `dart run build_runner build --delete-conflicting-outputs` (or `watch` during active dev)

## Task Table

| Task ID | Description | Requirement(s) | Dependencies | Planned Files | Status |
|---------|-------------|----------------|--------------|---------------|--------|
| T-001 | Project bootstrap: declare dependencies in pubspec.yaml; define shared constants (memosBoxName='memos', MemoModel typeId=0). Configure environment.sdk `>=3.2.0 <4.0.0`, iOS 11.0 / Android SDK 21 minimums. No TDD cycle (scaffolding prerequisite). | (infra for all) | - | pubspec.yaml; lib/core/constants/app_constants.dart | pending |
| T-002 | Memo entity TDD cycle: RED memo_test.dart (copyWith, value equality, field invariants) → GREEN immutable Memo value object (id, title?, content, createdAt, updatedAt) → REFACTOR. Pure Dart, zero external deps. | Foundation for REQ-MEMO-002/004/006/007 | T-001 | lib/domain/entities/memo.dart; test/unit/domain/entities/memo_test.dart | pending |
| T-003 | Domain contract + UseCases TDD cycle: RED 4 usecase tests with mock MemoRepository → GREEN abstract MemoRepository interface (@MX:ANCHOR) + CreateMemo (id/createdAt/updatedAt via uuid v4 + DateTime.now().toUtc()), GetMemos (updatedAt DESC sort + empty handling), UpdateMemo (updatedAt refresh, createdAt preserved), DeleteMemo → REFACTOR. | REQ-MEMO-002, REQ-MEMO-004, REQ-MEMO-007, REQ-MEMO-008 | T-002 | lib/domain/repositories/memo_repository.dart; lib/domain/usecases/{create_memo,get_memos,update_memo,delete_memo}.dart; test/unit/domain/usecases/{create_memo,get_memos,update_memo,delete_memo}_test.dart | pending |
| T-004 | MemoModel + Hive adapter: GREEN MemoModel with @HiveType(typeId: 0) (@MX:ANCHOR — must stay 0) + @HiveField on each field, fromMemo factory + toMemo method. Run build_runner to generate memo_model.g.dart. Conversion correctness verified via T-006 repo test. | REQ-MEMO-002 (persistence model) | T-002 | lib/data/models/memo_model.dart (+ generated memo_model.g.dart) | pending |
| T-005 | MemoLocalDataSource (Hive box CRUD): GREEN abstract interface + MemoLocalDataSourceImpl using Hive.box<MemoModel>('memos') for create/getAll/update/delete. | REQ-MEMO-002, REQ-MEMO-004, REQ-MEMO-007, REQ-MEMO-008 (local storage) | T-004 | lib/data/datasources/local/memo_local_datasource.dart | pending |
| T-006 | MemoRepositoryImpl TDD cycle: RED memo_repository_impl_test.dart with mock LocalDataSource (CRUD + entity↔model conversion) → GREEN MemoRepositoryImpl (LocalDataSource only, no network; getAll sort updatedAt DESC @MX:NOTE) → REFACTOR conversion logic. | REQ-MEMO-004, REQ-MEMO-009 (offline via local-only impl) | T-003, T-005 | lib/data/repositories/memo_repository_impl.dart; test/unit/data/repositories/memo_repository_impl_test.dart | pending |
| T-007 | Riverpod providers: GREEN @riverpod codegen providers — memoLocalDataSourceProvider, memoRepositoryProvider, memosProvider (AsyncNotifier: load + updatedAt DESC sort), memoNotifierProvider (create/update/delete actions). Run build_runner to generate memo_provider.g.dart. Exercised via widget tests T-009/T-010. | REQ-MEMO-004 (list state), REQ-MEMO-002/007/008 (actions) | T-006 | lib/presentation/state/memo_provider.dart (+ generated memo_provider.g.dart) | pending |
| T-008 | MemoCard widget TDD cycle: RED memo_card_test.dart (title-or-content-preview rendering, updatedAt relative time, onTap/onLongPress callbacks) → GREEN MemoCard widget → REFACTOR const constructor optimization. | REQ-MEMO-004 (display), REQ-MEMO-006 (tap target), REQ-MEMO-008 (long-press target) | T-002 | lib/presentation/widgets/memo_card.dart; test/widget/memo_card_test.dart | pending |
| T-009 | HomePage TDD cycle: RED home_page_test.dart (empty-state message; populated list in updatedAt DESC; FAB present) → GREEN HomePage ConsumerWidget (FAB → /memo/new; MemoCard ListView or EmptyState; long-press → delete confirm dialog) → REFACTOR. | REQ-MEMO-001, REQ-MEMO-004, REQ-MEMO-005, REQ-MEMO-008 | T-007, T-008 | lib/presentation/pages/home_page.dart; test/widget/home_page_test.dart | pending |
| T-010 | Editor + routing + bootstrap TDD cycle: RED memo_editor_page_test.dart (empty-content validation blocks save; save flow; create vs edit mode pre-fill) → GREEN MemoEditorPage (title TextField optional, content TextField required multiline, validation), GoRouter (/ , /memo/new, /memo/:id via context.go, routerProvider pattern), main.dart (Hive.initFlutter + registerAdapter + openBox awaited before runApp — @MX:ANCHOR; ProviderScope + MaterialApp.router) → REFACTOR extract route path constants, HiveError→AppException handling. | REQ-MEMO-001, REQ-MEMO-002, REQ-MEMO-003, REQ-MEMO-006, REQ-MEMO-007, REQ-MEMO-010 (platform-identical bootstrap) | T-007, T-009 | lib/presentation/pages/memo_editor_page.dart; lib/core/router/app_router.dart; lib/main.dart; test/widget/memo_editor_page_test.dart | pending |

## Requirement Traceability

| Requirement | Covered by Task(s) | Verification |
|-------------|--------------------|--------------|
| REQ-MEMO-001 (create nav) | T-009, T-010 | Widget test: FAB → /memo/new create mode |
| REQ-MEMO-002 (save) | T-003, T-004, T-005, T-006, T-010 | UseCase + repo + editor widget tests |
| REQ-MEMO-003 (empty validation) | T-010 | Editor widget test: empty content blocks save |
| REQ-MEMO-004 (list DESC) | T-003, T-006, T-007, T-008, T-009 | UseCase sort test + HomePage widget test |
| REQ-MEMO-005 (empty state) | T-009 | HomePage widget test: empty-state message |
| REQ-MEMO-006 (edit nav + prefill) | T-008, T-010 | Editor widget test: edit mode pre-fill |
| REQ-MEMO-007 (update save) | T-003, T-006, T-010 | UpdateMemo test (createdAt preserved) + editor test |
| REQ-MEMO-008 (delete confirm) | T-003, T-006, T-009 | DeleteMemo test + HomePage confirm dialog test |
| REQ-MEMO-009 (offline) | T-006 (cross-cutting) | Architectural: LocalDataSource-only, no network calls (acceptance Scenario 8) |
| REQ-MEMO-010 (platform parity) | T-001, T-010 (cross-cutting) | pubspec/Podfile/build.gradle minimums + identical Dart bootstrap (acceptance Scenario 9, dual-platform run) |

## Notes

- REQ-MEMO-009 and REQ-MEMO-010 are non-functional / cross-cutting: satisfied by architecture (Hive-only, no network branch) and platform config (iOS 11.0 / Android SDK 21). Verified at integration/manual stage per acceptance Scenarios 8 and 9, not by a dedicated unit test.
- T-001, T-004, T-005, T-007 are GREEN-dominant (config/codegen/glue with no dedicated test file in the SPEC); their correctness is validated transitively by downstream test tasks (T-006, T-009, T-010).
- TDD ordering within the SPEC: all unit tests (T-002, T-003, T-006) pass before widget tests (T-008, T-009, T-010), per acceptance.md TDD Criteria.
- MX tags to add during implementation: MemoRepository @MX:ANCHOR, MemoModel typeId @MX:ANCHOR, main.dart Hive init @MX:ANCHOR, MemoRepositoryImpl.getAll @MX:NOTE.

## Open Decision (blocks Run phase — requires user approval)

Library versions pinned in the SPEC diverge from current stable (June 2026). See execution plan "Approval Points". Default recommendation: follow SPEC-pinned versions for internal consistency. Confirm before Run phase begins.
