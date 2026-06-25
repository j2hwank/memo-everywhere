// Widget tests for home page auth integration (SPEC-BACKEND-001)
//
// Tests define the contract:
//   - AppBar shows person_outline icon when logged out
//   - AppBar shows person icon (or account info) when logged in

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/presentation/pages/home_page.dart';
import 'package:memo_everywhere/presentation/state/auth_provider.dart';
import 'package:memo_everywhere/presentation/state/memo_provider.dart';
import 'widget_test_helpers.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeMemosNotifier extends AutoDisposeAsyncNotifier<List<Memo>>
    implements Memos {
  @override
  Future<List<Memo>> build() async => [];
}

class _FakeMemoNotifier extends AutoDisposeNotifier<void>
    implements MemoNotifier {
  @override
  void build() {}

  @override
  Future<void> create({String? title, required String content}) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> update({
    required Memo memo,
    String? title,
    required String content,
    bool clearTitle = false,
  }) async {}
}

class _FakeAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> register(String email, String password) async {}

  @override
  Future<void> logout() async {}
}

Widget buildHomePage(AuthState authState) {
  return ProviderScope(
    overrides: [
      ...syncProviderOverrides,
      memosProvider.overrideWith(() => _FakeMemosNotifier()),
      memoNotifierProvider.overrideWith(() => _FakeMemoNotifier()),
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(authState)),
    ],
    child: const MaterialApp(home: HomePage()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HomePage — account icon (logged out)', () {
    testWidgets('shows person_outline icon when user is logged out',
        (tester) async {
      await tester.pumpWidget(buildHomePage(const AuthLoggedOut()));
      await tester.pump();

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });
  });

  group('HomePage — account icon (logged in)', () {
    testWidgets('shows person icon when user is logged in', (tester) async {
      await tester.pumpWidget(
        buildHomePage(const AuthLoggedIn(email: 'user@test.com')),
      );
      await tester.pump();

      // When logged in, we show the filled person icon
      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });
}
