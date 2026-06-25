# Changelog

All notable changes to memo-everywhere are documented in this file.

Format: [SPEC-ID] — Date — Description

---

## [0.3.0] — 2026-06-25

### Added (SPEC-BACKEND-001: FastAPI 백엔드 + 크로스디바이스 동기화)

- **FastAPI 백엔드 서버**: PostgreSQL + SQLAlchemy + Alembic 스택
  - JWT 인증 (Access 24h, Refresh 30d), bcrypt 비밀번호 암호화
  - 메모 CRUD REST API (5개 엔드포인트)
  - 마지막 수정 우선(Last-Write-Wins) 동기화 전략
  - 증분 동기화 지원 (`?since=` 쿼리)
  - Whisper API 프록시 (`POST /voice/transcribe`)
- **Flutter 동기화 클라이언트**: Dio HTTP, flutter_secure_storage로 토큰 관리
  - `memo_remote_datasource.dart`: REST API 통신
  - `auth_remote_datasource.dart`: JWT 로그인/회원가입
  - `sync_service.dart`: 자동 동기화 로직
  - `connectivity_plus`: 네트워크 상태 감지
- **테스트**: pytest 21/21 통과 (FastAPI 엔드포인트 전수)

### Added (SPEC-VOICE-001: 음성 메모 녹음 + STT)

- **음성 녹음**: `record` 패키지로 플랫폼별 코덱 지원 (AAC/MP4/WAV)
  - `audio_local_datasource.dart`: 로컬 오디오 파일 관리
  - `voice_recorder.dart`: 위젯 UI (녹음/정지/재생)
- **네이티브 STT**: `speech_to_text` 패키지 (ko-KR, en-US)
  - `voice_record_page.dart`: 음성 녹음 화면
  - `record_voice.dart`: UseCase 로직
- **클라우드 STT 폴백**: Whisper API (네트워크 연결 + 사용자 옵트인)
  - `voice_provider.dart`: 상태 관리
- **테스트**: flutter test 109/109 통과

### Added (SPEC-WEB-MARKDOWN-001: Flutter Web 지원)

- **Flutter Web 플랫폼**: `web/` 디렉토리, `flutter build web` 완성
  - 반응형 레이아웃 (모바일/태블릿/데스크톱)
  - `platform_utils.dart`: 플랫폼 감지 유틸리티

### Reverted

- **마크다운 렌더링 철회**: 읽기 모드 마크다운 미리보기(`flutter_markdown`, `memo_detail_page.dart`)를
  제거하고 순수 텍스트 편집 방식으로 복원. 메모 탭 시 일반 텍스트 편집기로 직접 진입.
  - 사유: 옵시디안 스타일 인라인 실시간 렌더링이 목표였으나 Flutter에 적합한 구현 경로가 없어 범위에서 제외
- **테스트**: flutter test 112/112 통과

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
