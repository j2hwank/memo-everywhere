import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../presentation/pages/auth_screen.dart';
import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/memo_editor_page.dart';
import '../../presentation/pages/voice_record_page.dart';
import '../../presentation/state/memo_provider.dart';

part 'app_router.g.dart';

/// Route path constants — extracted to prevent typos across navigation calls.
abstract class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String newMemo = '/memo/new';
  static const String voice = '/voice';

  /// Optional login / account screen.
  static const String account = '/account';

  /// Returns the edit route for [id] (plain-text editor).
  static String editMemo(String id) => '/memo/$id';
}

// @MX:ANCHOR bootstrap invariant — router depends on memosProvider being available.
// @MX:REASON: All navigation targets consume Riverpod providers; the ProviderScope
//             must wrap MaterialApp.router before the router is constructed.
@riverpod
GoRouter router(RouterRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.newMemo,
        builder: (_, __) => const MemoEditorPage(),
      ),
      GoRoute(
        path: '/memo/:id',
        builder: (_, state) {
          // Tapping a memo opens the plain-text editor directly.
          final id = state.pathParameters['id']!;
          final memosAsync = ref.read(memosProvider);
          final memo = memosAsync.valueOrNull?.firstWhere(
            (m) => m.id == id,
            orElse: () => throw StateError('Memo $id not found'),
          );
          if (memo == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return MemoEditorPage(memo: memo);
        },
      ),
      GoRoute(
        path: AppRoutes.voice,
        builder: (_, __) => const VoiceRecordPage(),
      ),
      GoRoute(
        path: AppRoutes.account,
        builder: (_, __) => const AuthScreen(),
      ),
    ],
  );
}
