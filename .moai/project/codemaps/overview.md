# Architecture Overview: memo-everywhere

> 이 파일은 신규 프로젝트를 위한 플레이스홀더입니다. 구현이 시작된 후 `/moai codemaps` 명령으로 실제 코드베이스를 기반으로 자동 업데이트됩니다.

## 프로젝트 목표

음성 지원이 포함된 크로스플랫폼 메모 애플리케이션 — iOS, Android, macOS, Windows, Linux, Web 전체 지원.

## 계획된 아키텍처

- **패턴**: Clean Architecture (Presentation → Domain ← Data)
- **프론트엔드**: Flutter (Dart)
- **백엔드**: FastAPI (Python) + PostgreSQL
- **음성 처리**: 하이브리드 STT (온디바이스 + Whisper API 옵션)
- **동기화**: REST API 기반 클라우드 동기화

## 주요 도메인

| 도메인 | 설명 |
|--------|------|
| Memo | 메모 CRUD, 로컬 저장, 동기화 |
| Voice | 음성 녹음, STT 변환 |
| Tag | 태그/폴더 조직화 |
| Search | 전문 검색 |
| Auth | 인증/권한 |
| Sync | 클라우드 동기화 로직 |

---
_코드 구현 후 `/moai codemaps` 로 이 파일을 업데이트하세요._
