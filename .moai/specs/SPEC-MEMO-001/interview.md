# Interview: SPEC-MEMO-001 텍스트 메모 CRUD

## 초기 명확화
Question: MVP 첫 번째 SPEC으로 어떤 기능을 만들고 싶으신가요?
Answer: 텍스트 메모 CRUD — Memo 엔티티, 도메인 계층, Hive 로컬 저장소를 Clean Architecture로 구축. 음성·태그·검색·동기화 등 모든 이후 기능의 기초.

## Round 1: 범위
Question: 텍스트 메모 CRUD SPEC에 어떤 범위를 포함할까요?
Answer: 데이터 계층 + 홈 목록 + 편집 화면 — Memo 엔티티(제목선택, 내용필수, 타임스탬프), Hive 로컬 저장, Riverpod 상태관리, 홈 화면(메모 목록) + 편집 화면을 함께 구현. 실제 동작하는 화면 흐름을 MVP에서 확인.

## Round 2: 플랫폼 및 제약사항
Question: 첫 SPEC의 대상 플랫폼과 오프라인 지원 범위를 선택해주세요.
Answer: iOS + Android, 로컬 저장 오프라인 필수 — 모바일 2개 플랫폼 먼저 시작. Hive 로컬 DB로 100% 오프라인 동작 보장. macOS/Web 등은 Phase 2에서. 클라우드 동기화 없음(이 SPEC 범위 외).

## Clarity Score
Initial: 2/10
Final: 7/10
Rounds completed: 2
