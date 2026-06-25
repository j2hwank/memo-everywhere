---
name: project-spec-memo-001
description: SPEC-MEMO-001 Flutter offline memo CRUD MVP implementation status and key decisions
metadata:
  type: project
---

SPEC-MEMO-001 TDD implementation completed on 2026-06-25. All 26 files created (17 impl + 9 test).

**Why:** Greenfield Flutter app requiring offline-first Hive persistence with Clean Architecture.

**How to apply:** Flutter SDK is NOT installed on this machine (`flutter` command not found). All files were written manually. To run tests and build_runner codegen, user must install Flutter SDK first.

Key decisions:
- `memo_model.g.dart` and `memo_provider.g.dart` written manually (build_runner not runnable without Flutter SDK)
- `app_router.g.dart` also written manually for the same reason  
- iOS/Android platform directories do not exist yet — need `flutter create` to scaffold them
- `MemoEditorPage` receives `Memo?` directly (not via router path param) to simplify widget tests
- Empty-state text uses Korean: '메모가 없습니다'
- Validation error text uses Korean: '내용을 입력해 주세요'
- `copyWith` includes `clearTitle: bool` parameter to explicitly null out optional title field

Post-implementation steps user must run:
1. Install Flutter SDK (>=3.2.0)
2. `flutter pub get`
3. `dart run build_runner build --delete-conflicting-outputs` (regenerates .g.dart files properly)
4. `flutter test`
5. For iOS: set deployment target to 11.0 in ios/Podfile
6. For Android: set minSdkVersion 21 in android/app/build.gradle
