# SPEC-MEMO-001 아키텍처 문서

## 개요

SPEC-MEMO-001은 Clean Architecture 패턴을 따르는 Flutter 메모 앱의 기본 CRUD 기능입니다. 계층 구조는 **Presentation → Domain ← Data** 단방향 의존성을 엄격하게 유지합니다.

---

## 레이어 다이어그램

```
┌─────────────────────────────────────────────────────────┐
│ PRESENTATION LAYER (UI & State Management)              │
│ ┌─────────────────┐  ┌──────────────────┐              │
│ │ HomePage        │  │ MemoEditorPage   │              │
│ │ (Consumer)      │  │ (ConsumerStateful│              │
│ │ ├─ MemoCard     │  │  Widget)         │              │
│ │ └─ ListView     │  └──────────────────┘              │
│ └────────────┬────┘                                     │
│              │ uses                                      │
│ ┌────────────▼────────────────────────────────────────┐ │
│ │ Riverpod Providers (memo_provider.dart)             │ │
│ │ ├─ memosProvider: AsyncNotifier<List<Memo>>         │ │
│ │ ├─ memoNotifierProvider: MemoNotifier (actions)     │ │
│ │ └─ memoRepositoryProvider: MemoRepository           │ │
│ └────────────┬────────────────────────────────────────┘ │
└─────────────┼────────────────────────────────────────────┘
              │ depends on
┌─────────────▼────────────────────────────────────────────┐
│ DOMAIN LAYER (Business Logic - Framework Independent)   │
│ ┌──────────────────────────┐                            │
│ │ Entities                 │                            │
│ │ └─ Memo (value object)   │                            │
│ └──────────────────────────┘                            │
│ ┌──────────────────────────────────────────────────┐   │
│ │ Repository Interface                             │   │
│ │ └─ MemoRepository (abstract contract)            │   │
│ └──────────────────────────────────────────────────┘   │
│ ┌──────────────────────────────────────────────────┐   │
│ │ Use Cases                                        │   │
│ │ ├─ CreateMemo(repository, entity)               │   │
│ │ ├─ GetMemos(repository)                         │   │
│ │ ├─ UpdateMemo(repository, entity)               │   │
│ │ └─ DeleteMemo(repository, id)                   │   │
│ └──────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
              ▲ implemented by
┌─────────────┴────────────────────────────────────────────┐
│ DATA LAYER (External Frameworks & Data Persistence)     │
│ ┌──────────────────────────────────────────────────┐   │
│ │ Data Sources                                     │   │
│ │ └─ MemoLocalDataSource                           │   │
│ │    ├─ Box<MemoModel> (Hive)                     │   │
│ │    └─ CRUD: create(), getAll(), update(), delete() │ │
│ └──────────────────────────────────────────────────┘   │
│ ┌──────────────────────────────────────────────────┐   │
│ │ Models & Adapters                                │   │
│ │ └─ MemoModel (Hive TypeAdapter)                  │   │
│ │    ├─ @HiveType(typeId: 0)                       │   │
│ │    └─ Fields: id, title, content, createdAt,    │   │
│ │           updatedAt (Hive serializable)         │   │
│ └──────────────────────────────────────────────────┘   │
│ ┌──────────────────────────────────────────────────┐   │
│ │ Repository Implementation                        │   │
│ │ └─ MemoRepositoryImpl                             │   │
│ │    └─ Uses: MemoLocalDataSource                  │   │
│ │    └─ Converts: MemoModel ↔ Memo                 │   │
│ └──────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────┘
```

---

## 각 계층의 파일 목록 및 역할

### Core 계층 (공유 설정)

| 파일 | 역할 | 핵심 내용 |
|------|------|---------|
| `lib/core/constants/app_constants.dart` | 애플리케이션 상수 정의 | `memosBoxName = 'memos'`, typeId 값 |
| `lib/core/router/app_router.dart` | go_router 설정 (`@MX:ANCHOR`) | 라우트 정의 및 `AppRoutes` 상수 |

### Domain 계층 (비즈니스 로직, 외부 의존성 없음)

| 파일 | 역할 | 구현 내용 |
|------|------|---------|
| `lib/domain/entities/memo.dart` | Memo 값 객체 | 불변(immutable) 엔티티, `copyWith()`, 동등성 |
| `lib/domain/repositories/memo_repository.dart` | 저장소 인터페이스 (`@MX:ANCHOR`) | 추상 계약: `create()`, `getAll()`, `update()`, `delete()` |
| `lib/domain/usecases/create_memo.dart` | 메모 생성 UseCase | 입력 → UUID + timestamp 생성 → 저장소 호출 |
| `lib/domain/usecases/get_memos.dart` | 메모 목록 조회 UseCase | 저장소에서 가져온 후 **updatedAt DESC 정렬** |
| `lib/domain/usecases/update_memo.dart` | 메모 수정 UseCase | `createdAt` 보존, `updatedAt` 갱신 |
| `lib/domain/usecases/delete_memo.dart` | 메모 삭제 UseCase | ID로 저장소 삭제 호출 |

### Data 계층 (Hive 저장소 구현)

| 파일 | 역할 | 구현 내용 |
|------|------|---------|
| `lib/data/models/memo_model.dart` | Hive 모델 + TypeAdapter (`@MX:ANCHOR`) | Hive 직렬화 (@HiveType typeId=0), 5개 필드 |
| `lib/data/datasources/local/memo_local_datasource.dart` | 로컬 데이터 소스 | Hive Box CRUD 구현, MemoModel 직접 조작 |
| `lib/data/repositories/memo_repository_impl.dart` | 저장소 구현 | LocalDataSource 사용, MemoModel ↔ Memo 변환 |

### Presentation 계층 (UI & Riverpod 상태)

| 파일 | 역할 | 구현 내용 |
|------|------|---------|
| `lib/presentation/state/memo_provider.dart` | Riverpod 프로바이더 | AsyncNotifier, 상태 관리, 액션 |
| `lib/presentation/widgets/memo_card.dart` | 메모 카드 위젯 | 제목/미리보기 렌더링, tap/long-press 콜백 |
| `lib/presentation/pages/home_page.dart` | 홈 페이지 | ListView, 빈 상태, FAB, long-press 삭제 |
| `lib/presentation/pages/memo_editor_page.dart` | 메모 편집 페이지 | 생성/편집 모드, 입력 검증, 저장 흐름 |

### Entry Point

| 파일 | 역할 | 핵심 내용 |
|------|------|---------|
| `lib/main.dart` | 앱 진입점 (`@MX:ANCHOR`) | Hive 초기화, ProviderScope, MaterialApp.router |

---

## 의존성 흐름

### Presentation 계층 → Domain 계층

**memosProvider** (Riverpod AsyncNotifier) 
  ↓ uses
**GetMemos UseCase** 
  ↓ uses
**MemoRepository** (interface)

**memoNotifierProvider** (Riverpod action methods)
  ↓ uses
**CreateMemo, UpdateMemo, DeleteMemo UseCases** 
  ↓ use
**MemoRepository** (interface)

### Domain 계층 ← Data 계층

**MemoRepository** (interface in domain)
  ↑ implemented by
**MemoRepositoryImpl** (in data)
  ↑ uses
**MemoLocalDataSource** 
  ↑ uses
**Hive Box<MemoModel>**

### Riverpod 프로바이더 체인

```dart
// Data layer provider
memoLocalDataSourceProvider → MemoLocalDataSourceImpl

// Repository provider
memoRepositoryProvider → MemoRepositoryImpl
  └─ uses: memoLocalDataSourceProvider

// Domain use cases (implicit, via repository)
memosProvider (list) → GetMemos → memoRepositoryProvider
memoNotifierProvider (actions) → CreateMemo/UpdateMemo/DeleteMemo → memoRepositoryProvider
```

**핵심**: 모든 프로바이더는 `memoRepositoryProvider`에 의존하며, 이는 `memoLocalDataSourceProvider`를 통해 Hive에 접근합니다.

---

## Hive 초기화 및 부트스트랩 불변식

### 초기화 순서 (`main.dart`, `@MX:ANCHOR`)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Hive 초기화 (Flutter 환경 설정)
  await Hive.initFlutter();
  
  // 2. MemoModel TypeAdapter 등록
  Hive.registerAdapter(MemoModelAdapter());
  
  // 3. 'memos' Box 열기
  await Hive.openBox<MemoModel>('memos');
  
  // 4. 앱 실행 (위 모든 단계 완료 후)
  runApp(const ProviderScope(child: MainApp()));
}
```

**불변식**: 
- **모든 Hive 접근은 `main()` 완료 후에만 가능**
- `Hive.box<MemoModel>('memos')`는 initialized 상태를 전제
- `MemoLocalDataSourceImpl`은 box가 열려있다고 가정 (lazy init 없음)

### TypeId 할당

| 모델 | typeId | 설명 |
|------|--------|------|
| MemoModel | 0 | **예약됨, 변경 불가** (기존 박스 손상 위험) |
| (Future) | 1, 2, 3... | 향후 모델용 |

---

## Riverpod 프로바이더 상세 설명

### 1. memoLocalDataSourceProvider

**역할**: Hive Box 접근의 싱글톤

```dart
@riverpod
MemoLocalDataSource memoLocalDataSource(ref) {
  return MemoLocalDataSourceImpl();
}
```

**특징**:
- Hive box는 애플리케이션 전체에서 싱글톤
- `Hive.box<MemoModel>('memos')` 호출 (initialized 가정)

### 2. memoRepositoryProvider

**역할**: 도메인 저장소 인터페이스 구현 제공

```dart
@riverpod
MemoRepository memoRepository(ref) {
  final dataSource = ref.watch(memoLocalDataSourceProvider);
  return MemoRepositoryImpl(dataSource);
}
```

**특징**:
- Domain 계층의 `MemoRepository` 인터페이스를 Presentation에 노출
- 의존성 주입으로 테스트 가능

### 3. memosProvider

**역할**: 메모 목록 (비동기, 정렬됨)

```dart
@riverpod
class Memos extends _$Memos {
  @override
  Future<List<Memo>> build() async {
    final repository = ref.watch(memoRepositoryProvider);
    return repository.getAll(); // updatedAt DESC 정렬됨
  }
  
  // 목록 동기화 메서드
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.getAll());
  }
}
```

**특징**:
- `AsyncNotifier` 사용 (비동기 상태 관리)
- 자동 캐싱 및 상태 추적
- UI에서 `memosProvider.watch()`로 구독

### 4. memoNotifierProvider

**역할**: 메모 CRUD 액션 메서드

```dart
@riverpod
class MemoNotifier extends _$MemoNotifier {
  @override
  void build() {} // 상태 없음 (액션 전용)
  
  Future<void> create(String content) async { /* ... */ }
  Future<void> update(Memo memo) async { /* ... */ }
  Future<void> delete(String id) async { /* ... */ }
}
```

**특징**:
- 상태 없는 노티파이어 (액션 컨테이너)
- 각 액션은 `memosProvider` 무효화 후 다시 로드
- UI에서 `memoNotifierProvider.read()`로 호출

---

## 네비게이션 구조 (go_router)

**라우트 경로**:

| 경로 | 페이지 | 모드 | 목적 |
|------|--------|------|------|
| `/` | HomePage | - | 메모 목록 표시 |
| `/memo/new` | MemoEditorPage | create | 새 메모 작성 |
| `/memo/:id` | MemoEditorPage | edit | 기존 메모 수정 |

**네비게이션 예시**:

```dart
// HomePage에서 새 메모 생성 페이지로
context.go('/memo/new');

// 메모 ID를 이용해 편집 페이지로
context.go('/memo/$memoId');

// 홈으로 돌아가기
context.go('/');
```

---

## 주요 설계 결정

### 1. Clean Architecture 선택 이유

✅ **계층 분리**로 테스트 용이
- Domain 계층은 프레임워크 독립적
- 각 계층을 독립적으로 단위 테스트 가능

✅ **의존성 역전**으로 확장성
- Data 계층(Hive)을 나중에 교체 가능 (예: SQLite, Firebase)
- 저장소 인터페이스만 유지하면 됨

✅ **비즈니스 로직 보호**
- UseCase가 프레임워크 변화에 영향받지 않음

### 2. Riverpod 코드 생성 사용 이유

✅ **유형 안전성**: `@riverpod` 애너테이션으로 자동 생성
✅ **간단한 구문**: 함수 기반 provider 선언
✅ **의존성 추적**: `ref.watch()` 자동 추적

### 3. Hive 로컬 저장소 선택 이유

✅ **빠른 성능**: In-memory + disk caching
✅ **간단한 API**: key-value 모델
✅ **타입 안전성**: TypeAdapter로 구조화된 모델 지원
✅ **플랫폼 호환성**: iOS/Android 동일 동작

### 4. go_router 선택 이유

✅ **타입 안전 라우팅**: URL 문자열 대신 코드 생성
✅ **Deep linking 지원**: URI 기반 내비게이션
✅ **간단한 설정**: 선언적 라우트 정의

---

## 테스트 전략

### 단위 테스트 (Unit Tests)

**Domain 계층**:
- Memo 엔티티: copyWith, 동등성
- UseCase: 저장소 호출, 정렬, 타임스탬프

**Data 계층**:
- MemoRepositoryImpl: 엔티티/모델 변환
- MemoModel: Hive 직렬화

### 위젯 테스트 (Widget Tests)

**HomePage**: 빈 상태, 메모 목록 렌더링
**MemoEditorPage**: 입력 검증, 저장 흐름, 모드 전환
**MemoCard**: 제목/미리보기, tap/long-press 콜백

---

## 앞으로의 확장 포인트

### Phase 2: 음성 메모
- Domain: `MemoAudio` 엔티티 추가
- Data: `MemoModel` 필드 확장 (audioPath)
- Presentation: 녹음 UI

### Phase 3: 태그 & 검색
- Domain: `Tag` 엔티티, 검색 UseCase
- Data: Hive 인덱싱
- Presentation: 검색 페이지, 태그 필터

### Phase 4: 클라우드 동기화
- Data: NetworkDataSource 추가
- Domain: 저장소 인터페이스 확장 (sync 메서드)
- Presentation: 동기화 상태 UI

---

**마지막 업데이트**: 2026-06-25
