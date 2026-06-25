---
spec_id: SPEC-SEARCH-001
title: "메모 검색 기능 — 제목/내용 키워드 검색"
status: completed
created: 2026-06-25
completed: 2026-06-25
methodology: tdd
parent_spec: SPEC-MEMO-001
---

# SPEC-SEARCH-001: 메모 검색 기능 — 제목/내용 키워드 검색

## HISTORY

- v1.0.0 — 2026-06-25 — initial draft
- v1.1.0 — 2026-06-25 — implementation complete (TDD RED-GREEN-REFACTOR)

## Implementation Notes

구현이 SPEC 요구사항과 100% 일치하여 완료되었습니다.

### 구현된 파일

| 파일 | 구분 | 내용 |
|------|------|------|
| `lib/domain/usecases/search_memos.dart` | 신규 | `SearchMemos` UseCase — 순수 동기 Dart 함수 |
| `lib/presentation/state/memo_provider.dart` | 수정 | `searchQueryProvider` (StateProvider) + `filteredMemosProvider` (@riverpod) 추가 |
| `lib/presentation/state/memo_provider.g.dart` | 자동생성 | build_runner codegen 업데이트 |
| `lib/presentation/pages/home_page.dart` | 수정 | ConsumerStatefulWidget 전환, 검색 UI (300ms debounce), 검색 결과 없음 상태 |
| `test/unit/domain/usecases/search_memos_test.dart` | 신규 | T-001~T-007 (단위 테스트, mock 불필요) |
| `test/widget/home_page_search_test.dart` | 신규 | T-008~T-012 (위젯 테스트) |
| `analysis_options.yaml` | 수정 | codegen info suppression 추가 |

### 테스트 결과

- 신규 테스트: 12개 (T-001~T-012) 통과
- 기존 테스트: 57개 유지 (SPEC-MEMO-001)
- **전체: 69개 통과**
- `flutter analyze`: No issues found

### MX Tag 추가 내역

- `@MX:ANCHOR` on `SearchMemos.call()` — `filteredMemosProvider`가 의존하는 필터링 계약
- `@MX:NOTE` on `_onSearchChanged()` — 300ms debounce 의도 문서화

## 1. 개요 (Overview)

### 기능 목적

이 SPEC은 사용자가 메모 목록에서 원하는 메모를 키워드로 빠르게 찾을 수 있도록 **제목/내용 기반 검색 기능**을 정의한다. 사용자는 홈 화면에서 검색 모드로 전환한 뒤 검색어를 입력하고, 입력과 동시에 제목 또는 내용에 해당 키워드를 포함하는 메모만 실시간으로 필터링하여 볼 수 있다. 검색은 대소문자를 구분하지 않으며, 검색어를 지우면 즉시 전체 목록으로 복귀한다.

메모 수가 증가할수록 목록 스크롤만으로 특정 메모를 찾기 어려워지므로, 검색은 CRUD MVP(SPEC-MEMO-001) 위에 얹는 첫 번째 사용성 강화 기능이다.

### SPEC-MEMO-001과의 관계

본 SPEC은 완료된 `SPEC-MEMO-001`(텍스트 메모 CRUD MVP)을 부모로 하는 확장 기능이다.

- SPEC-MEMO-001이 구축한 `Memo` 엔티티, `memosProvider`(AsyncNotifier), `HomePage`를 **재사용**한다.
- SPEC-MEMO-001의 Exclusions 항목 중 "4. 검색(Search)"으로 명시적으로 제외되었던 기능을 본 SPEC에서 충족한다.
- Clean Architecture 의존성 방향(Presentation → Domain ← Data)과 TDD(RED-GREEN-REFACTOR) 방식을 그대로 계승한다.

### 기술 접근 방식 (Hive 인메모리 필터링)

Hive는 전문(full-text) 검색을 지원하지 않으므로, 검색은 **저장소 계층이 아닌 메모리 상에서 수행**한다.

- 이미 `memosProvider`가 전체 메모 목록을 메모리에 로드해 두었으므로, 추가 디스크/저장소 접근 없이 로드된 리스트를 Dart 문자열 비교로 필터링한다.
- 필터링은 순수 Dart 로직(`SearchMemos` UseCase)으로 구현하여 테스트 용이성을 확보하고 Data 계층 변경을 회피한다.
- 메모가 1000개 이하인 한 동기 인메모리 필터링은 UI 스레드에서 충분히 빠르므로 `compute`(isolate)는 사용하지 않는다.

## 2. 요구사항 (EARS Requirements)

### REQ-SEARCH-001: 실시간 검색 필터링 (AC-1)
WHEN the user types text into the search field, the system SHALL immediately display only the memos whose title or content contains that text, matching case-insensitively. WHILE the user is typing, the system SHALL debounce filter execution by 300ms to avoid filtering on every keystroke.

### REQ-SEARCH-002: 검색 결과 없음 상태 (AC-2)
IF no memo matches the current search query, WHEN the search query is non-empty, THEN the system SHALL display the message "검색 결과가 없습니다".

### REQ-SEARCH-003: 검색 초기화 (AC-3)
WHEN the search field is empty, the system SHALL display the full memo list (identical to the non-search HomePage state).

### REQ-SEARCH-004: 검색 범위 — 제목과 내용 (AC-4)
WHERE a memo is being matched against a query, the system SHALL search both the `title` (nullable) and `content` fields. IF a memo's `title` is null, WHEN matching against a query, THEN the system SHALL still match the memo by its `content` field without error.

### REQ-SEARCH-005: 검색 모드 진입 (AC-5)
WHEN HomePage is loaded, the system SHALL display a search icon in the AppBar. WHEN the user taps the search icon, the system SHALL switch into search mode, replacing the AppBar title with an active search input field.

### REQ-SEARCH-006: 검색 모드 종료 (AC-5)
WHILE in search mode, WHEN the user taps the back/close action, the system SHALL exit search mode, clear the current query, and return to the full memo list.

### REQ-SEARCH-007: 인메모리 필터링 성능 (AC-6)
WHERE the total number of memos is at most 1000, the system SHALL perform filtering synchronously on the UI thread using the already-loaded in-memory list, and SHALL NOT introduce additional Hive/storage reads or `compute` isolates for filtering.

## 3. 아키텍처 설계 (Architecture Design)

본 기능은 SPEC-MEMO-001이 구축한 Clean Architecture를 그대로 따르며, 인메모리 필터링이므로 Data 계층과 Router는 변경하지 않는다.

### Domain Layer (신규)

- **`SearchMemos` UseCase** — 순수 Dart 필터링 로직.
  - 시그니처: `List<Memo> call(String query, List<Memo> memos)`
  - `query`가 빈 문자열(또는 공백만)인 경우 입력 `memos`를 그대로 반환한다.
  - `title`과 `content` 모두를 대상으로, 대소문자를 무시한 부분 문자열(substring) 매칭을 수행한다.
  - `title`이 null인 메모는 `content`만으로 매칭한다(NPE 없이 안전 처리).
  - 비동기/저장소 의존성 없음 — 동기 순수 함수. 테스트 시 mock 불필요.

### Presentation Layer (수정)

- **`searchQueryProvider`** — `StateProvider<String>`. 현재 검색어를 보관한다. 초기값은 빈 문자열.
- **`filteredMemosProvider`** — `Provider<AsyncValue<List<Memo>>>`. `memosProvider`(원본 비동기 목록)와 `searchQueryProvider`(검색어)를 조합한다.
  - `memosProvider`의 `AsyncValue`를 `whenData`로 받아 `SearchMemos`로 필터링한 결과를 다시 `AsyncValue`로 노출한다.
  - 로딩/에러 상태는 `memosProvider`의 상태를 그대로 전파한다.
- **`home_page.dart` 수정** — AppBar에 검색 아이콘 추가, 검색 모드 토글 상태(검색 모드 여부) 관리, 검색바 입력을 300ms 디바운스 후 `searchQueryProvider`에 반영, 목록 출처를 `memosProvider`에서 `filteredMemosProvider`로 전환.

### 수정 대상 파일

| 파일 | 구분 | 변경 내용 |
|------|------|----------|
| `lib/domain/usecases/search_memos.dart` | 신규 | `SearchMemos` UseCase |
| `lib/presentation/state/memo_provider.dart` | 수정 | `searchQueryProvider`, `filteredMemosProvider` 추가 |
| `lib/presentation/pages/home_page.dart` | 수정 | 검색 아이콘, 검색 모드 토글, 디바운스, 결과 없음 상태 |

### 신규 파일 없는 레이어 (변경 없음)

- **Data Layer**: 변경 없음. 인메모리 필터링이므로 `MemoRepository`/`MemoLocalDataSource`/`MemoRepositoryImpl` 모두 수정하지 않는다.
- **Router**: 변경 없음. 별도 검색 페이지를 만들지 않고 홈 화면에서 인라인으로 검색을 처리하므로 `app_router.dart`의 라우트(`/`, `/memo/new`, `/memo/:id`)는 그대로 유지한다.
- **Entity**: 변경 없음. `Memo` 엔티티는 그대로 사용한다.

## 4. 테스트 계획 (Test Plan)

방법론은 TDD(RED-GREEN-REFACTOR)이며, 모든 테스트는 구현 전에 실패 상태로 먼저 작성한다.

### 단위 테스트 — `test/unit/domain/usecases/search_memos_test.dart`

| ID | 시나리오 | 검증 내용 |
|----|----------|----------|
| T-001 | 빈 쿼리 | 빈 문자열(또는 공백) 쿼리 → 전체 메모 그대로 반환 |
| T-002 | 제목 키워드 매칭 | `title`에 키워드 포함 시 해당 메모 반환 |
| T-003 | 내용 키워드 매칭 | `content`에 키워드 포함 시 해당 메모 반환 |
| T-004 | 대소문자 무시 | "Hello" 쿼리로 "hello world" 내용 메모 매칭 |
| T-005 | title null 메모 | `title == null` 메모도 `content`로 매칭, NPE 없음 |
| T-006 | 일치 없음 | 어떤 메모와도 일치하지 않는 쿼리 → 빈 리스트 |
| T-007 | 부분 문자열 매칭 | "로그" 쿼리로 "회의 로그 정리" 메모 매칭 |

### 위젯 테스트 — `test/widget/home_page_search_test.dart`

| ID | 시나리오 | 검증 내용 |
|----|----------|----------|
| T-008 | 검색 아이콘 표시 | AppBar에 검색 아이콘 위젯 존재 |
| T-009 | 검색 모드 전환 | 검색 아이콘 탭 → AppBar가 검색 입력바로 전환 |
| T-010 | 입력 시 필터링 | 검색어 입력 → 필터링된 목록만 표시 |
| T-011 | 검색어 지움 | 검색어를 비우면 → 전체 목록 복귀 |
| T-012 | 결과 없음 메시지 | 매칭 없는 검색어 → "검색 결과가 없습니다" 표시 |

## 5. 인수 기준 요약 (Acceptance Criteria Summary)

| AC | 제목 | 핵심 기준 | 관련 REQ |
|----|------|----------|----------|
| AC-1 | 실시간 검색 필터링 | 입력 즉시 제목/내용 포함 메모 표시, 대소문자 무시, 300ms 디바운스 | REQ-SEARCH-001 |
| AC-2 | 검색 결과 없음 상태 | 일치 메모 없을 때 "검색 결과가 없습니다" 표시 | REQ-SEARCH-002 |
| AC-3 | 검색 초기화 | 검색창이 비면 전체 메모 목록 표시 | REQ-SEARCH-003 |
| AC-4 | 검색 범위 | title(nullable) + content 모두 대상, title null도 검색 가능 | REQ-SEARCH-004 |
| AC-5 | 검색 UI | AppBar 검색 아이콘 → 검색바 전환 → 뒤로가기 시 전체 목록 복귀 | REQ-SEARCH-005, REQ-SEARCH-006 |
| AC-6 | 성능 | 1000개 이하 인메모리 동기 필터링, compute 불필요 | REQ-SEARCH-007 |

## 6. 완료 조건 (Definition of Done)

- [ ] `SearchMemos` UseCase 구현 및 단위 테스트(T-001 ~ T-007) 통과
- [ ] `searchQueryProvider`, `filteredMemosProvider` 구현
- [ ] `HomePage` 검색 UI 구현 (검색 아이콘, 검색 모드 토글, 디바운스, 결과 없음 상태) 및 위젯 테스트(T-008 ~ T-012) 통과
- [ ] 모든 테스트 통과 (`flutter test`)
- [ ] `flutter analyze`: 0 errors, 0 warnings

## 7. Exclusions (What NOT to Build)

본 SPEC은 제목/내용 키워드 기반의 인메모리 검색에만 집중하며, 아래 항목은 명시적으로 범위에서 제외한다:

1. **태그/메타데이터 기반 검색** — 태그, 카테고리, 생성일/수정일 범위 필터링은 제외한다(키워드 검색만).
2. **전문(Full-Text) 검색 인덱싱** — 형태소 분석, 검색 인덱스, 랭킹/스코어링, 퍼지(fuzzy) 매칭은 제외한다(단순 부분 문자열 매칭만).
3. **검색 히스토리 / 자동완성** — 최근 검색어 저장, 추천어, 자동완성 UI는 제외한다.
4. **검색 결과 하이라이팅** — 매칭된 키워드의 텍스트 강조 표시는 제외한다.
5. **별도 검색 페이지 / 라우트** — 전용 검색 화면이나 신규 go_router 라우트는 만들지 않는다(홈 화면 인라인 처리만).
6. **저장소/서버 측 검색** — Hive 쿼리 확장, 백엔드 검색 API, 1000개 초과 대용량 데이터셋 최적화(페이지네이션, isolate 필터링)는 제외한다.
7. **정렬 옵션 변경** — 검색 결과의 정렬 기준은 기존 `updatedAt DESC`를 그대로 유지하며, 관련도순 등 정렬 변경은 제외한다.

## MX Tag Strategy

검색 기능 구현 단계에서 다음 MX 태그를 추가한다:

- `SearchMemos.call()`: `@MX:ANCHOR` (필터링 계약 — `filteredMemosProvider`가 의존하는 핵심 로직)
- `SearchMemos.call()` 내 title null 처리 분기: `@MX:NOTE` (nullable title 안전 매칭 이유 설명)
- `home_page.dart` 디바운스 로직: `@MX:NOTE` (300ms 디바운스 의도 — 키 입력마다 필터링 방지)
