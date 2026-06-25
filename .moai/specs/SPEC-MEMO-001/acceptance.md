# Acceptance Criteria: SPEC-MEMO-001 텍스트 메모 CRUD MVP

## Given/When/Then Scenarios

### Scenario 1: 메모 생성 성공 (Happy Path)
**Given** HomePage가 로드되어 있고 사용자가 새 메모를 작성하려 한다
**When** 사용자가 FAB(생성 버튼)를 탭하여 MemoEditorPage(생성 모드)로 이동하고, 내용(content)을 입력한 뒤 Save를 탭한다
**Then** 메모가 Hive 로컬 저장소에 저장되고 HomePage로 돌아간다
**And** 새로 생성된 메모가 목록 최상단(updatedAt DESC)에 표시된다
(REQ-MEMO-001, REQ-MEMO-002, REQ-MEMO-004)

### Scenario 2: 메모 편집 성공 (Happy Path)
**Given** HomePage에 기존 메모가 하나 이상 존재한다
**When** 사용자가 MemoCard를 탭하여 MemoEditorPage(편집 모드)로 이동하고, 기존 내용이 채워진 상태에서 내용을 수정한 뒤 Save를 탭한다
**Then** 기존 Memo가 새 내용과 새 updatedAt 타임스탬프로 Hive에서 갱신된다
**And** createdAt은 보존되고, 수정된 메모가 목록 최상단으로 재정렬되어 표시된다
(REQ-MEMO-006, REQ-MEMO-007, REQ-MEMO-004)

### Scenario 3: 확인 후 메모 삭제 (Happy Path)
**Given** HomePage에 삭제할 메모가 존재한다
**When** 사용자가 MemoCard를 길게 누르거나(long-press) 삭제 아이콘을 탭하고, 확인 다이얼로그에서 확인(confirm)을 선택한다
**Then** 해당 메모가 Hive에서 삭제되고 목록에서 제거된다
**And** 삭제된 메모는 더 이상 HomePage에 표시되지 않는다
(REQ-MEMO-008)

### Scenario 4: 메모 목록 표시 (Happy Path, Populated)
**Given** Hive에 여러 개의 메모가 서로 다른 updatedAt 값으로 저장되어 있다
**When** HomePage가 로드된다
**Then** 모든 메모가 updatedAt DESC(최신순) 순서로 목록에 표시된다
**And** 각 MemoCard에 제목(없으면 content 미리보기)과 updatedAt 상대 시간이 표시된다
(REQ-MEMO-004)

### Scenario 5: 빈 내용 검증 (Edge Case, Save Blocked)
**Given** 사용자가 MemoEditorPage에서 내용(content) 필드를 비워둔 상태이다
**When** 사용자가 Save를 탭한다
**Then** 검증 오류 메시지가 표시되고 메모는 저장되지 않는다
**And** 화면은 MemoEditorPage에 머무른다
(REQ-MEMO-003)

### Scenario 6: 빈 상태 (Edge Case, No Memos)
**Given** Hive에 저장된 메모가 하나도 없다
**When** HomePage가 로드된다
**Then** 빈 상태(empty state) 메시지가 표시된다
**And** 목록 영역에 MemoCard가 렌더링되지 않으며 FAB는 정상 표시된다
(REQ-MEMO-005)

### Scenario 7: 제목 없는 메모 저장 (Edge Case, Title Optional)
**Given** 사용자가 MemoEditorPage에서 제목(title)은 비우고 내용(content)만 입력한다
**When** 사용자가 Save를 탭한다
**Then** 제목이 null인 메모가 정상적으로 Hive에 저장된다
**And** HomePage의 MemoCard에는 제목 대신 content 미리보기가 표시된다
(REQ-MEMO-002)

### Scenario 8: 오프라인 메모 생성 (Offline Scenario)
**Given** 기기에 네트워크 연결이 없다(오프라인 상태)
**When** 사용자가 새 메모를 생성하고 Save를 탭한다
**Then** 메모가 Hive 로컬 저장소에 정상 저장되고 기능 저하 없이 동작한다
**And** 목록 조회·수정·삭제 등 모든 CRUD 기능이 온라인과 동일하게 동작한다
(REQ-MEMO-009)

### Scenario 9: 플랫폼 일관성 (Cross-Platform)
**Given** 동일한 앱이 iOS 11.0+ Simulator와 Android SDK 21+ Emulator에서 각각 실행된다
**When** 사용자가 두 플랫폼에서 동일한 메모 CRUD 작업을 수행한다
**Then** 두 플랫폼에서 동일한 동작과 결과(저장, 정렬, 검증)가 관찰된다
(REQ-MEMO-010)

## Performance Criteria

- HomePage 로드 시간: 메모 최대 100개까지 500ms 미만(< 500ms)으로 화면 렌더링이 완료되어야 한다.

## TDD Criteria

- 모든 단위 테스트(unit tests)가 통과한 후에 위젯 테스트(widget tests)를 진행한다.
- 모든 위젯 테스트가 통과한 후에 통합 테스트(integration tests)를 진행한다.
- 구현 코드보다 테스트를 먼저 작성한다(Red-Green-Refactor).

## Platform Criteria

- iOS Simulator와 Android Emulator 양쪽에서 테스트를 수행한다.
- 두 플랫폼에서 모든 시나리오(Scenario 1–9)가 동일하게 통과해야 한다.

## Definition of Done

- [ ] 모든 EARS 요구사항(REQ-MEMO-001 ~ REQ-MEMO-010) 구현 완료
- [ ] 모든 Given/When/Then 시나리오(Scenario 1–9) 통과
- [ ] 단위 → 위젯 → 통합 테스트 순서로 전부 통과
- [ ] 코드 커버리지 85% 이상
- [ ] HomePage 로드 < 500ms (메모 100개 기준)
- [ ] iOS Simulator + Android Emulator 양쪽 검증 완료
- [ ] TRUST 5 품질 게이트 통과
- [ ] MX 태그 추가 (MemoRepository @MX:ANCHOR, main.dart Hive 초기화 @MX:ANCHOR 등)
