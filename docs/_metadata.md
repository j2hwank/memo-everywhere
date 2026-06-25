---
title: Project Metadata
tags: [metadata, project-info, obsidian]
created: 2026-06-25
modified: 2026-06-25
aliases: [프로젝트메타데이터, 프로젝트정보]
---

# Project Metadata: memo-everywhere

Obsidian Vault 메타데이터 및 프로젝트 정보

---

## 기본 정보

| 항목 | 값 |
|------|-----|
| **프로젝트명** | memo-everywhere |
| **설명** | 모든 플랫폼에서 음성 지원이 되는 크로스플랫폼 메모 애플리케이션 |
| **생성 날짜** | 2026-06-25 |
| **상태** | Planning Phase (SPEC 작성 중) |
| **팀 리더** | Kwon |
| **저장소** | /Users/kwon/MyDevel/memo-everywhere |

---

## 주요 특성

### 기술 스택
- **Frontend**: Flutter (Dart)
- **Backend**: FastAPI (Python)
- **Database**: PostgreSQL
- **Local Storage**: Hive
- **State Management**: Riverpod
- **Platforms**: iOS, Android, macOS, Windows, Linux, Web

### 핵심 기능
- 텍스트 메모 CRUD
- 음성 녹음 + STT (Whisper API + 디바이스 네이티브)
- 태그/폴더 조직화
- 풍부한 검색
- 클라우드 동기화

### 아키텍처
- Clean Architecture
- Feature-based modules
- Repository Pattern
- Riverpod for state management

---

## 문서 구조

### Vault 폴더 구조

```
memo-everywhere/
├── docs/                    # 마크다운 문서 (Obsidian vault)
│   ├── index.md             # 메인 진입점
│   ├── product.md           # 제품 정의
│   ├── structure.md         # 프로젝트 구조
│   ├── tech.md              # 기술 스택
│   ├── _metadata.md         # 이 파일
│   ├── voice-processing.md  # (작성 예정)
│   ├── sync-strategy.md     # (작성 예정)
│   └── ...                  # 추가 문서
└── .moai/project/           # 프로젝트 설정
    ├── product.md           # 프로젝트 정의 (원본)
    ├── structure.md         # 구조 정의 (원본)
    └── tech.md              # 기술 정의 (원본)
```

### 핵심 문서

| 문서 | 설명 | 태그 |
|------|------|------|
| [[index]] | 전체 프로젝트 개요 및 네비게이션 | project, index |
| [[product]] | 제품 정의, 기능, 사용 사례 | product, features |
| [[structure]] | 디렉토리 구조, 아키텍처 | architecture, structure |
| [[tech]] | 기술 스택, 의존성, 개발 환경 | technology, framework |

### 작성 예정 문서

| 문서 | 설명 |
|------|------|
| voice-processing | 음성 처리 구현 상세 |
| sync-strategy | 데이터 동기화 전략 |
| database-options | 데이터베이스 선택 상세 |
| api-specification | 백엔드 API 명세 |
| design-system | UI/UX 디자인 시스템 |
| setup-guide | 개발 환경 설정 가이드 |
| coding-standards | 코딩 표준 및 컨벤션 |
| testing-strategy | 테스트 전략 |

---

## Obsidian 활용

### 위키링크 문법
```
[[문서명]] - 문서로 링크
[[문서명#섹션]] - 특정 섹션으로 링크
[[문서명|표시명]] - 다른 이름으로 표시
```

### 태그 사용
```
#product - 제품 관련
#technology - 기술 관련
#architecture - 아키텍처 관련
#feature/voice - 음성 기능
#layer/presentation - 프레젠테이션 계층
#package/flutter - Flutter 패키지
```

### 그래프 뷰
Obsidian의 그래프 뷰에서 모든 문서의 연결 관계를 시각화:
- 노드: 각 문서
- 엣지: 위키링크로 표시된 연결

---

## 문서 작성 규칙

### 프론트매터 (YAML)
```yaml
---
title: 문서 제목
tags: [tag1, tag2]
created: 2026-06-25
modified: 2026-06-25
aliases: [별칭1, 별칭2]
---
```

### 제목 계층
```markdown
# H1 - 문서 제목 (파일명과 동일)
## H2 - 주요 섹션
### H3 - 부분 섹션
#### H4 - 상세 내용
```

### 링크 스타일
- 내부 링크: `[[문서명]]`
- 외부 링크: `[텍스트](URL)`
- 앵커: `[[문서명#섹션]]`

### 코드 블록
```dart
// Dart 코드
final list = <String>[];
```

```python
# Python 코드
def hello():
    print("Hello")
```

---

## 프로젝트 진행 단계

### Phase 1: 계획 (Planning) ✅ 진행 중
- [ ] 제품 정의 문서 작성
- [ ] 기술 스택 결정
- [ ] 프로젝트 구조 설계
- [ ] 아키텍처 문서화

### Phase 2: 설계 (Design)
- [ ] UI/UX 디자인
- [ ] API 명세서 작성
- [ ] 데이터베이스 스키마 설계

### Phase 3: 개발 (Development)
- [ ] Flutter 프론트엔드 구현
- [ ] FastAPI 백엔드 구현
- [ ] 통합 테스트

### Phase 4: 배포 (Deployment)
- [ ] 앱 스토어 배포 (iOS, Android)
- [ ] 서버 배포
- [ ] 모니터링 및 유지보수

---

## 관련 파일

### 프로젝트 구성 파일
- `.moai/project/product.md` - 원본 제품 정의
- `.moai/project/structure.md` - 원본 구조 정의
- `.moai/project/tech.md` - 원본 기술 정의
- `.moai/project/interview.md` - 프로젝트 인터뷰 기록

### 설정 파일
- `pubspec.yaml` - Flutter 의존성
- `requirements.txt` - Python 의존성
- `.env.example` - 환경 변수 템플릿

### 코드 디렉토리
- `lib/` - Flutter 소스코드
- `test/` - 테스트
- `backend/` - FastAPI 서버

---

## 팀 정보

### 팀 멤버
- **Kwon** (리더) - 전체 조율

### 역할 분담
- 프론트엔드: Flutter 개발
- 백엔드: FastAPI 개발
- 인프라: Docker, 배포

---

## 다음 단계

1. **API 명세서 작성**
   - 메모 CRUD 엔드포인트
   - 태그 관리 엔드포인트
   - 인증 엔드포인트
   - 음성 처리 엔드포인트

2. **UI/UX 디자인**
   - 와이어프레임 작성
   - 디자인 시스템 정의
   - 프로토타입 제작

3. **개발 환경 설정**
   - Flutter 프로젝트 초기화
   - FastAPI 프로젝트 초기화
   - 데이터베이스 설정

4. **첫 번째 기능 구현**
   - 메모 CRUD (텍스트)
   - 기본 UI

---

## 참고자료

### 공식 문서
- [Flutter Official](https://flutter.dev)
- [FastAPI Official](https://fastapi.tiangolo.com)
- [PostgreSQL Docs](https://www.postgresql.org/docs)
- [Riverpod Documentation](https://riverpod.dev)

### 커뮤니티
- Flutter 한국 커뮤니티
- Reddit r/Flutter
- Stack Overflow

---

## 마지막 업데이트

- **작성**: 2026-06-25
- **수정**: 2026-06-25
- **작성자**: Kwon

---

**Obsidian Vault 준비 완료!** 🎉

이제 Obsidian에서 이 문서들을 연 후, 그래프 뷰에서 모든 연결을 시각화할 수 있습니다.

폴더 경로: `/Users/kwon/MyDevel/memo-everywhere/docs/`
