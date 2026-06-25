# SPEC-MEMO-001 (Compact)

> Run phase 전용 압축 버전. 전체 맥락은 spec.md 참조.

## EARS Requirements

- **REQ-MEMO-001**: WHEN the user taps the FAB/create button on HomePage, the system SHALL navigate to MemoEditorPage in create mode.
- **REQ-MEMO-002**: WHEN the user taps Save on MemoEditorPage with non-empty content, the system SHALL persist the Memo to Hive local storage and navigate back to HomePage.
- **REQ-MEMO-003**: IF the content field is empty, WHEN the user taps Save, THEN the system SHALL display a validation error and SHALL NOT save.
- **REQ-MEMO-004**: WHEN HomePage is loaded, the system SHALL display all memos from Hive in reverse chronological order (updatedAt DESC).
- **REQ-MEMO-005**: IF no memos exist, WHEN HomePage is loaded, THEN the system SHALL display an empty state message.
- **REQ-MEMO-006**: WHEN the user taps a MemoCard on HomePage, the system SHALL navigate to MemoEditorPage in edit mode with the existing memo content pre-filled.
- **REQ-MEMO-007**: WHEN the user taps Save on MemoEditorPage in edit mode, the system SHALL update the existing Memo in Hive with new content and a new updatedAt timestamp.
- **REQ-MEMO-008**: WHEN the user long-presses a MemoCard or taps the delete icon, the system SHALL show a confirmation dialog; WHEN confirmed, the system SHALL delete the memo from Hive and remove it from the list.
- **REQ-MEMO-009**: WHERE network is unavailable, the system SHALL continue to function fully using Hive local data with no degradation.
- **REQ-MEMO-010**: WHERE running on iOS 11.0+ or Android SDK 21+, the system SHALL behave identically.

## Given/When/Then Scenarios

### Scenario 1: 메모 생성 성공
**Given** HomePage가 로드되어 있고 사용자가 새 메모를 작성하려 한다
**When** 사용자가 FAB를 탭하여 MemoEditorPage(생성 모드)로 이동하고, 내용을 입력한 뒤 Save를 탭한다
**Then** 메모가 Hive에 저장되고 HomePage로 돌아간다
**And** 새 메모가 목록 최상단(updatedAt DESC)에 표시된다

### Scenario 2: 메모 편집 성공
**Given** HomePage에 기존 메모가 하나 이상 존재한다
**When** 사용자가 MemoCard를 탭해 편집 모드로 이동하고, 내용을 수정한 뒤 Save를 탭한다
**Then** 기존 Memo가 새 내용과 새 updatedAt으로 갱신된다
**And** createdAt은 보존되고 수정된 메모가 최상단으로 재정렬된다

### Scenario 3: 확인 후 메모 삭제
**Given** HomePage에 삭제할 메모가 존재한다
**When** 사용자가 MemoCard를 길게 누르거나 삭제 아이콘을 탭하고 확인을 선택한다
**Then** 해당 메모가 Hive에서 삭제되고 목록에서 제거된다
**And** 삭제된 메모는 더 이상 표시되지 않는다

### Scenario 4: 메모 목록 표시 (채워진 상태)
**Given** Hive에 여러 메모가 서로 다른 updatedAt으로 저장되어 있다
**When** HomePage가 로드된다
**Then** 모든 메모가 updatedAt DESC 순서로 표시된다
**And** 각 MemoCard에 제목(없으면 content 미리보기)과 updatedAt 상대 시간이 표시된다

### Scenario 5: 빈 내용 검증 (저장 차단)
**Given** 사용자가 MemoEditorPage에서 내용 필드를 비워둔 상태이다
**When** 사용자가 Save를 탭한다
**Then** 검증 오류가 표시되고 메모는 저장되지 않는다
**And** 화면은 MemoEditorPage에 머무른다

### Scenario 6: 빈 상태 (메모 없음)
**Given** Hive에 저장된 메모가 하나도 없다
**When** HomePage가 로드된다
**Then** 빈 상태 메시지가 표시된다
**And** MemoCard가 렌더링되지 않으며 FAB는 정상 표시된다

### Scenario 7: 제목 없는 메모 저장
**Given** 사용자가 제목은 비우고 내용만 입력한다
**When** 사용자가 Save를 탭한다
**Then** 제목이 null인 메모가 정상 저장된다
**And** MemoCard에는 제목 대신 content 미리보기가 표시된다

### Scenario 8: 오프라인 메모 생성
**Given** 기기에 네트워크 연결이 없다
**When** 사용자가 새 메모를 생성하고 Save를 탭한다
**Then** 메모가 Hive에 정상 저장되고 기능 저하가 없다
**And** 모든 CRUD 기능이 온라인과 동일하게 동작한다

### Scenario 9: 플랫폼 일관성
**Given** 앱이 iOS 11.0+ Simulator와 Android SDK 21+ Emulator에서 실행된다
**When** 두 플랫폼에서 동일한 CRUD 작업을 수행한다
**Then** 두 플랫폼에서 동일한 동작과 결과가 관찰된다

## Files to Create

### Flutter Project Root
- `pubspec.yaml`

### Core Layer
- `lib/core/constants/app_constants.dart`
- `lib/core/router/app_router.dart`

### Domain Layer
- `lib/domain/entities/memo.dart`
- `lib/domain/repositories/memo_repository.dart`
- `lib/domain/usecases/create_memo.dart`
- `lib/domain/usecases/get_memos.dart`
- `lib/domain/usecases/update_memo.dart`
- `lib/domain/usecases/delete_memo.dart`

### Data Layer
- `lib/data/models/memo_model.dart`
- `lib/data/datasources/local/memo_local_datasource.dart`
- `lib/data/repositories/memo_repository_impl.dart`

### Presentation Layer
- `lib/presentation/state/memo_provider.dart`
- `lib/presentation/widgets/memo_card.dart`
- `lib/presentation/pages/home_page.dart`
- `lib/presentation/pages/memo_editor_page.dart`

### Entry
- `lib/main.dart`

### Tests
- `test/unit/domain/entities/memo_test.dart`
- `test/unit/domain/usecases/create_memo_test.dart`
- `test/unit/domain/usecases/get_memos_test.dart`
- `test/unit/domain/usecases/update_memo_test.dart`
- `test/unit/domain/usecases/delete_memo_test.dart`
- `test/unit/data/repositories/memo_repository_impl_test.dart`
- `test/widget/memo_card_test.dart`
- `test/widget/home_page_test.dart`
- `test/widget/memo_editor_page_test.dart`

## Exclusions (What NOT to Build)

1. 음성 입력 / STT(Speech-to-Text)
2. 태그(Tags) / 분류 / 폴더
3. 클라우드 동기화(Cloud Sync) / 백엔드 API / 다중 기기
4. 검색(Search) / 필터링
5. 인증(Authentication) / 로그인 / 계정
6. 데스크톱·웹 플랫폼 (macOS, Windows, Linux, Web)
7. 리치 텍스트(Rich Text) / 마크다운 / 이미지·첨부
