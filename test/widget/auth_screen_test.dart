// Widget tests for AuthScreen (SPEC-BACKEND-001 auth)
//
// Tests define the contract:
//   - login form shows 이메일 and 비밀번호 fields
//   - tapping 로그인 button calls notifier.login with entered email/password
//   - tapping 회원가입 button toggles to register form
//   - loading indicator shown during auth in progress
//   - error message shown when AuthError state
//   - home page account icon shows person_outline when logged out

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/presentation/pages/auth_screen.dart';
import 'package:memo_everywhere/presentation/state/auth_provider.dart';

// ---------------------------------------------------------------------------
// Fake AuthNotifier for widget tests (does NOT extend AuthNotifier to avoid
// ref dependency; implements the same interface via duck typing via overrideWith)
// ---------------------------------------------------------------------------

class FakeAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  AuthState _state;
  final List<({String email, String password})> loginCalls = [];
  final List<({String email, String password})> registerCalls = [];

  FakeAuthNotifier(this._state);

  @override
  AuthState build() => _state;

  void setState(AuthState s) {
    _state = s;
    state = s;
  }

  @override
  Future<void> login(String email, String password) async {
    loginCalls.add((email: email, password: password));
  }

  @override
  Future<void> register(String email, String password) async {
    registerCalls.add((email: email, password: password));
  }

  @override
  Future<void> logout() async {}
}

Widget buildAuthScreenWithFake(FakeAuthNotifier notifier) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => notifier),
    ],
    child: const MaterialApp(home: AuthScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AuthScreen — login form', () {
    testWidgets('shows email and password text fields', (tester) async {
      final notifier = FakeAuthNotifier(const AuthLoggedOut());
      await tester.pumpWidget(buildAuthScreenWithFake(notifier));
      await tester.pump();

      expect(find.text('이메일'), findsOneWidget);
      expect(find.text('비밀번호'), findsOneWidget);
    });

    testWidgets('shows 로그인 ElevatedButton in login mode', (tester) async {
      final notifier = FakeAuthNotifier(const AuthLoggedOut());
      await tester.pumpWidget(buildAuthScreenWithFake(notifier));
      await tester.pump();

      // The ElevatedButton should have '로그인' text (AppBar title also shows
      // '로그인' so we target the ElevatedButton specifically)
      expect(find.widgetWithText(ElevatedButton, '로그인'), findsOneWidget);
    });

    testWidgets('tapping 로그인 ElevatedButton calls notifier.login with entered values',
        (tester) async {
      final notifier = FakeAuthNotifier(const AuthLoggedOut());
      await tester.pumpWidget(buildAuthScreenWithFake(notifier));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, '이메일'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '비밀번호'),
        'mypassword',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pump();

      expect(notifier.loginCalls.length, equals(1));
      expect(notifier.loginCalls.first.email, equals('test@example.com'));
      expect(notifier.loginCalls.first.password, equals('mypassword'));
    });
  });

  group('AuthScreen — register toggle', () {
    testWidgets('tapping register toggle button switches to register mode',
        (tester) async {
      final notifier = FakeAuthNotifier(const AuthLoggedOut());
      await tester.pumpWidget(buildAuthScreenWithFake(notifier));
      await tester.pump();

      // In login mode, the toggle shows text containing '회원가입'
      expect(find.textContaining('회원가입'), findsWidgets);

      // Tap the TextButton that toggles to register mode
      await tester.tap(find.widgetWithText(TextButton, '계정이 없으신가요? 회원가입'));
      await tester.pump();

      // After toggling, the submit ElevatedButton should say '회원가입'
      expect(find.widgetWithText(ElevatedButton, '회원가입'), findsOneWidget);
    });
  });

  group('AuthScreen — loading state', () {
    testWidgets('shows CircularProgressIndicator when AuthLoading',
        (tester) async {
      final notifier = FakeAuthNotifier(const AuthLoading());
      await tester.pumpWidget(buildAuthScreenWithFake(notifier));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AuthScreen — error state', () {
    testWidgets('shows error message when AuthError', (tester) async {
      final notifier =
          FakeAuthNotifier(const AuthError(message: '이메일 또는 비밀번호가 올바르지 않습니다'));
      await tester.pumpWidget(buildAuthScreenWithFake(notifier));
      await tester.pump();

      expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다'), findsOneWidget);
    });
  });
}
