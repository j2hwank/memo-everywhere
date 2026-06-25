---
title: memo-everywhere 프로젝트
tags: [project, index, memo-everywhere]
created: 2026-06-25
modified: 2026-06-25
aliases: [프로젝트 홈, 메모 어디서나]
---

# memo-everywhere 프로젝트

모든 플랫폼에서 음성 지원이 되는 크로스플랫폼 메모 애플리케이션입니다.

## 핵심 정보

| 항목 | 설명 |
|------|------|
| **프로젝트명** | memo-everywhere |
| **앱 타입** | 크로스플랫폼 메모 애플리케이션 |
| **지원 플랫폼** | iOS, Android, macOS, Windows, Linux, Web |
| **주요 기능** | 텍스트 메모, 음성 STT, 태그/폴더, 검색, 클라우드 동기화 |
| **개발 언어** | Dart (Flutter), Python (FastAPI) |

## 문서 네비게이션

### 📋 프로젝트 개요
- [[product]] - 제품 정의, 기능, 사용 사례, 타겟 오디언스

### 🏗 아키텍처
- [[structure]] - 디렉토리 구조, 레이어 설명, 모듈 구성
- [[architecture-diagram]] (Coming soon)

### 🛠 기술 스택
- [[tech]] - 기술 선택, 의존성, 개발 환경, 배포 설정
- [[flutter-stack]]
- [[backend-stack]]
- [[voice-processing]]
- [[database-options]]

### 🔄 동기화 및 데이터
- [[sync-strategy]] (Coming soon)
- [[data-models]] (Coming soon)

### 🎨 설계 및 UI/UX
- [[design-system]] (Coming soon)
- [[ui-components]] (Coming soon)

### 📝 개발 가이드
- [[setup-guide]] (Coming soon)
- [[coding-standards]] (Coming soon)
- [[testing-strategy]] (Coming soon)

### 📚 참고자료
- [[_metadata]] - 프로젝트 메타데이터

---

## 빠른 참조

### 프로젝트 구조
```
memo-everywhere/
├── lib/              # Flutter 소스코드 (Clean Architecture)
├── test/             # 테스트
├── docs/             # 마크다운 문서 (이 위치)
└── backend/          # FastAPI 서버 (별도 구성)
```

### 주요 의사결정
- **플랫폼**: Flutter (모든 플랫폼 지원)
- **음성**: Whisper API + 디바이스 네이티브 STT (하이브리드)
- **상태관리**: Riverpod
- **로컬 DB**: Hive
- **백엔드**: FastAPI + PostgreSQL

### 관련 파일
- `.moai/project/product.md` - 제품 정의
- `.moai/project/structure.md` - 프로젝트 구조
- `.moai/project/tech.md` - 기술 스택

---

## 최근 업데이트

- **2026-06-25**: 초기 문서 작성, Obsidian 통합 준비

## 다음 단계

1. [[design-system]] 작성 - UI/UX 가이드라인
2. [[setup-guide]] 작성 - 개발 환경 설정
3. [[api-spec]] 작성 - 백엔드 API 명세
4. 각 모듈별 상세 문서 작성

---

**Obsidian Vault**: 이 문서는 Obsidian과 완전히 호환됩니다. 그래프 뷰에서 모든 연결을 시각화할 수 있습니다.
