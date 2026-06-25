---
spec_id: SPEC-VOICE-001
title: "음성 메모 기능 — 녹음 + STT 텍스트 변환"
status: implemented
version: 1.0.1
created: 2026-06-25
updated: 2026-06-25
author: manager-spec
priority: high
methodology: tdd
dependencies: [SPEC-MEMO-001, SPEC-BACKEND-001]
---

# SPEC-VOICE-001: 음성 메모 기능

## HISTORY

- v1.0.1 — 2026-06-25 — implementation complete, all ACs pass
- v1.0.0 — 2026-06-25 — initial draft

## 메타데이터
- **상태**: draft
- **버전**: 1.0.0
- **생성일**: 2026-06-25
- **의존성**: SPEC-MEMO-001 (Memo 엔티티/저장소 재사용), SPEC-BACKEND-001 (REQ-V-003 클라우드 STT 폴백의 `POST /voice/transcribe` 엔드포인트)

## 개요

사용자가 음성을 녹음하여 자동으로 텍스트로 변환(STT)한 뒤 메모로 저장할 수 있는 **음성 메모 기능**을 정의한다. 기본 변환은 디바이스 네이티브 STT(`speech_to_text`)로 수행하며, 네트워크가 가용하고 사용자가 클라우드 STT를 활성화한 경우 FastAPI 백엔드를 경유한 Whisper API를 더 높은 정확도의 폴백으로 사용한다. 변환된 텍스트는 저장 전 사용자가 검토/수정할 수 있도록 메모 작성 화면에 미리 채워진다.

## 배경 및 동기

`product.md`의 핵심 기능 2번(음성 기록 및 STT, `#feature/voice`)과 사용 사례 1(이동 중 음성 메모), 사용 사례 2(회의록/강의 노트)를 충족한다. 운전 중이거나 손이 바쁜 상황에서 텍스트 입력은 비현실적이며, 음성 캡처는 빠른 아이디어 기록의 핵심 진입점이다. `product.md` 성공 지표는 STT 정확도 95% 이상을 목표로 하므로, 네이티브 STT를 기본으로 하되 정확도가 중요한 경우 Whisper 클라우드 폴백을 제공한다.

이 SPEC은 SPEC-MEMO-001이 구축한 `Memo` 엔티티와 메모 작성 흐름 위에 음성 입력 경로를 추가하는 확장 기능이다. 변환 결과는 일반 텍스트 메모와 동일하게 저장되므로 기존 CRUD/검색 기능과 자연스럽게 통합된다.

## 요구사항 (EARS 형식)

### 기능 요구사항

#### REQ-V-001: 녹음 시작
WHEN the user taps the voice record button, the system SHALL start audio recording using the `record` Flutter package.

#### REQ-V-002: 네이티브 STT 변환 (기본)
WHEN recording stops, the system SHALL convert the captured audio to text using the device native STT engine (`speech_to_text` package) as the primary transcription path.

#### REQ-V-003: 클라우드 STT 폴백 (선택)
WHERE network connectivity is available AND the user has enabled cloud STT, the system SHALL use the Whisper API via the FastAPI backend (`POST /voice/transcribe`, SPEC-BACKEND-001 REQ-B-006) as a fallback for higher transcription accuracy.

#### REQ-V-004: 변환 결과 사전 채움
WHEN STT completes, the system SHALL pre-fill the memo content field with the transcribed text so the user can review and edit it before saving.

#### REQ-V-005: 다국어 지원
The system SHALL support Korean (`ko-KR`) and English (`en-US`) as primary STT recognition languages.

#### REQ-V-006: 플랫폼별 오디오 코덱
The system SHALL record audio using the platform-appropriate codec: iOS (`.m4a` / AAC), Android (`.mp4` / AAC), Web (`.wav` / WAV), macOS (`.m4a` / AAC), Windows and Linux (`.wav` / WAV).

#### REQ-V-007: 녹음 화면 UI
The `VoiceRecordPage` SHALL display the elapsed recording duration, a real-time waveform visualization, and stop/cancel controls.

#### REQ-V-008: STT 실패 시 복구
IF STT fails (engine unavailable, no recognizable speech, or network error during cloud fallback), THEN the system SHALL persist the recorded audio file URL with the memo and allow the user to enter the transcription manually.

### 비기능 요구사항

- **성능**: 녹음 시작은 버튼 탭 후 500ms 이내에 시작되어야 한다(권한이 이미 부여된 경우). 네이티브 STT는 녹음 종료 후 변환을 즉시 시작한다.
- **권한**: 첫 녹음 시도 시 마이크 권한을 요청하며, 거부 시 사용자에게 설정 안내 메시지를 표시한다.
- **보안/프라이버시**: 클라우드 STT 폴백 사용 시에만 오디오가 외부로 전송되며, 네이티브 STT는 오프라인 온디바이스 처리로 외부 전송이 없다.
- **호환성**: `record` 및 `speech_to_text`가 지원하는 플랫폼(iOS/Android/Web/macOS/Windows/Linux) 전반에서 동작한다.
- **오프라인 동작**: 네트워크가 없어도 네이티브 STT로 변환 가능해야 한다(클라우드 폴백만 네트워크 의존).

## 구현 범위

### 포함 (In Scope)
- 마이크 권한 요청 및 처리
- `record` 패키지를 통한 플랫폼별 오디오 녹음
- `speech_to_text` 패키지를 통한 온디바이스 STT (한국어/영어)
- 네트워크 가용 + 사용자 활성화 시 Whisper 클라우드 STT 폴백 (백엔드 경유)
- 녹음 화면(`VoiceRecordPage`): 경과 시간, 파형 시각화, 정지/취소 컨트롤
- 변환 텍스트를 메모 작성 화면에 사전 채움 후 저장 전 사용자 검토/편집
- STT 실패 시 오디오 URL 보존 + 수동 전사 편집 경로
- 오디오 파일 로컬 저장(`AudioLocalDataSource`)

### 제외 (Out of Scope)
- **실시간(스트리밍) 받아쓰기 표시** — 녹음 중 실시간 자막/부분 결과 표시는 제외한다(녹음 종료 후 일괄 변환만).
- **AI 요약/생성** — `product.md` Non-Goal에 따라 음성 변환 결과의 AI 요약/재작성은 제외한다.
- **메모 번역** — `product.md` Non-Goal에 따라 변환 텍스트의 다국어 번역은 제외한다.
- **음성 명령/제어** — "메모 저장해줘" 같은 음성 커맨드 처리는 제외한다(받아쓰기 전용).
- **화자 분리(diarization)** — 다중 화자 구분 및 라벨링은 제외한다.
- **백엔드 Whisper 엔드포인트 구현 자체** — 해당 엔드포인트는 SPEC-BACKEND-001 REQ-B-006에서 구현하며, 본 SPEC은 클라이언트 호출만 담당한다.
- **오디오 파일 클라우드 업로드/동기화** — 오디오 바이너리의 서버 영구 저장/동기화는 본 SPEC 범위 외이다(텍스트 메모만 동기화 대상).

## 인수 조건 (Acceptance Criteria)

| # | 조건 | 검증 방법 |
|---|------|---------|
| AC-1 | 녹음 버튼 탭 시 `record` 패키지로 녹음이 시작됨 | 위젯 테스트: 버튼 탭 → 녹음 상태 진입, 모의 recorder의 `start()` 호출 검증 |
| AC-2 | 녹음 종료 시 `speech_to_text`로 변환이 수행됨 | 단위 테스트: 모의 STT 서비스에 오디오 경로 전달 → 변환 호출 검증 |
| AC-3 | 네트워크 가용 + 클라우드 STT 활성 시 `POST /voice/transcribe` 호출 | 단위 테스트: 네트워크 true + 플래그 true → 백엔드 데이터소스 호출, false → 네이티브 경로 |
| AC-4 | 변환 결과가 메모 작성 화면 content에 사전 채워짐 | 위젯 테스트: 변환 완료 → content TextField가 변환 텍스트로 채워짐 |
| AC-5 | 한국어/영어 인식 언어 설정이 STT에 전달됨 | 단위 테스트: `localeId`가 `ko-KR`/`en-US`로 전달되는지 검증 |
| AC-6 | 플랫폼별 코덱이 올바르게 선택됨 | 단위 테스트: 플랫폼별 `RecordConfig.encoder`/확장자 매핑 검증 |
| AC-7 | 녹음 화면에 경과 시간/파형/정지·취소 컨트롤이 표시됨 | 위젯 테스트: `VoiceRecordPage`에 duration 텍스트, 파형 위젯, stop/cancel 버튼 존재 |
| AC-8 | STT 실패 시 오디오 URL 보존 + 수동 편집 가능 | 단위/위젯 테스트: STT 실패 모킹 → voiceUrl 저장 + content 수동 입력 가능 |

## 기술 설계 (Technical Design)

SPEC-MEMO-001의 Clean Architecture(Presentation → Domain ← Data)를 따른다.

### 패키지 추가 (`pubspec.yaml`)

```yaml
dependencies:
  record: ^5.0.0
  speech_to_text: ^6.6.0
```

### 신규 파일

| 파일 | 레이어 | 역할 |
|------|--------|------|
| `lib/domain/usecases/record_voice.dart` | Domain | 녹음 시작/종료 + STT 변환 오케스트레이션 UseCase |
| `lib/presentation/pages/voice_record_page.dart` | Presentation | 녹음 화면 (시간/파형/정지·취소) |
| `lib/presentation/widgets/voice_recorder.dart` | Presentation | 파형 시각화 + 녹음 컨트롤 재사용 위젯 |
| `lib/presentation/state/voice_provider.dart` | Presentation | 녹음/변환 상태 Riverpod 프로바이더 |
| `lib/data/datasources/local/audio_local_datasource.dart` | Data | 오디오 파일 로컬 저장/조회 |

### 플랫폼별 코덱 매핑 (REQ-V-006)

```dart
// platform 분기는 SPEC-WEB-MARKDOWN-001의 platform_utils.dart와 공유
RecordConfig _configForPlatform() {
  if (kIsWeb) {
    return const RecordConfig(encoder: AudioEncoder.wav); // .wav
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return const RecordConfig(encoder: AudioEncoder.aacLc); // .m4a
  }
  if (Platform.isAndroid) {
    return const RecordConfig(encoder: AudioEncoder.aacLc); // .mp4 컨테이너
  }
  return const RecordConfig(encoder: AudioEncoder.wav); // Windows/Linux .wav
}
```

### STT 경로 선택 (REQ-V-002/003)

```dart
Future<String> transcribe(String audioPath, {required bool cloudEnabled}) async {
  final online = await _network.isConnected();
  if (cloudEnabled && online) {
    try {
      return await _backend.transcribe(audioPath); // POST /voice/transcribe
    } catch (_) {
      // 폴백 실패 시 네이티브로 재시도
    }
  }
  return await _nativeStt.recognize(audioPath, localeId: _selectedLocale);
}
```

### 백엔드 연동 (REQ-V-003)

- 클라우드 STT는 SPEC-BACKEND-001 `REQ-B-006`의 `POST /voice/transcribe`를 호출한다.
- 요청: multipart 오디오 파일, 응답: `{ "text": "..." }`.
- 인증은 SPEC-BACKEND-001의 JWT(`flutter_secure_storage` 보관)를 헤더에 포함한다.

## 구현 순서 (Implementation Order)

방법론: TDD (RED-GREEN-REFACTOR)

1. **Phase 1 — 권한 + 녹음**: 마이크 권한 처리, `record` 통합, 플랫폼별 코덱 매핑(REQ-V-001, V-006). `audio_local_datasource.dart` 저장.
2. **Phase 2 — 네이티브 STT**: `speech_to_text` 통합, 한/영 로케일(REQ-V-002, V-005), 변환 결과 반환.
3. **Phase 3 — 녹음 화면 UI**: `voice_record_page.dart` + `voice_recorder.dart`(시간/파형/정지·취소)(REQ-V-007), `voice_provider.dart` 상태 관리.
4. **Phase 4 — 메모 사전 채움**: 변환 결과를 메모 작성 화면 content에 주입(REQ-V-004).
5. **Phase 5 — 클라우드 폴백 + 실패 복구**: 백엔드 `/voice/transcribe` 연동(REQ-V-003), STT 실패 시 오디오 URL 보존 + 수동 편집(REQ-V-008). (SPEC-BACKEND-001 선행 필요)

> Phase 5는 SPEC-BACKEND-001의 `POST /voice/transcribe`에 의존한다. 백엔드 미완성 시 Phase 1~4까지 네이티브 경로로 독립 출시 가능하다.

## MX Tag Strategy

- `RecordVoice.transcribe()`: `@MX:ANCHOR` (STT 경로 선택 핵심 계약 — provider가 의존)
- 플랫폼별 코덱 분기: `@MX:NOTE` (플랫폼별 코덱 선택 이유 설명)
- 클라우드 폴백 try/catch: `@MX:WARN` (`@MX:REASON`: 네트워크/외부 API 실패 가능 영역, 네이티브 재시도 필요)
- 마이크 권한 요청 경로: `@MX:NOTE` (권한 거부 처리 의도)

## 참고 문서
- `.moai/project/product.md` — 핵심 기능 2(음성/STT), 사용 사례 1·2, 성공 지표(STT 정확도 95%)
- `.moai/project/tech.md` — `record`/`speech_to_text` 패키지, 오디오 코덱 정책
- `.moai/specs/SPEC-MEMO-001/spec.md` — Memo 엔티티/작성 흐름 (부모)
- `.moai/specs/SPEC-BACKEND-001/spec.md` — REQ-B-006 Whisper `/voice/transcribe` (의존)
