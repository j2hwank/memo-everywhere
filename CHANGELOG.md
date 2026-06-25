# Changelog

All notable changes to memo-everywhere are documented in this file.

Format: [SPEC-ID] — Date — Description

---

## [0.2.0] — 2026-06-25

### Added (SPEC-SEARCH-001: 메모 검색 기능)

- **실시간 키워드 검색**: 제목/내용 키워드 기반 인메모리 필터링
  - 대소문자 무시 (case-insensitive) 부분 문자열 매칭
  - 300ms 디바운스로 키 입력마다 필터링 방지
  - `title`이 null인 메모도 `content`로 안전하게 매칭
- **검색 UI**: AppBar 검색 아이콘 → 검색 입력바 전환 → 닫기 버튼으로 복귀
- **검색 결과 없음 상태**: "검색 결과가 없습니다" 메시지 표시
- **`SearchMemos` UseCase**: 순수 동기 Dart 함수 (의존성 없음, mock 불필요)
- **`searchQueryProvider`**: `StateProvider<String>` — 검색어 상태
- **`filteredMemosProvider`**: `@riverpod` — memosProvider와 searchQueryProvider 조합
- **플랫폼**: Android 지원 추가

### Tests

- 신규 12개 (T-001~T-012): 단위 테스트 7개 + 위젯 테스트 5개
- 전체 69개 통과

---

## [0.1.0] — 2026-06-25

### Added (SPEC-MEMO-001: 텍스트 메모 CRUD MVP)

- **메모 CRUD**: 생성, 조회, 수정, 삭제
- **오프라인 저장**: Hive 로컬 key-value 저장소
- **자동 정렬**: `updatedAt DESC` 순서로 목록 표시
- **메모 편집기**: 선택적 제목, 필수 내용 입력
- **빈 내용 검증**: 내용이 없으면 저장 차단 (ValidationError)
- **빈 상태 메시지**: 메모 없을 때 안내 문구 표시
- **macOS 한글 IME 완화**: 자모 조합 중 커서 이동 버그 앱 레벨 대응
- **Clean Architecture**: Presentation → Domain ← Data 계층 분리
- **플랫폼**: iOS, Android, macOS

### Tests

- 57개 통과 (단위 + 위젯)

---
