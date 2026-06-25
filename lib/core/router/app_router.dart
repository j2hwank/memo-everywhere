import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../constants/app_constants.dart';
import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/memo_editor_page.dart';
import '../../presentation/state/memo_provider.dart';

part 'app_router.g.dart';

/// Route path constants — extracted to prevent typos across navigation calls.
abstract class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String newMemo = '/memo/new';

  /// Returns the edit route for [id].
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
          // Edit mode: look up the memo from provider state.
          final id = state.pathParameters['id']!;
          // memosProvider is an AsyncNotifier; read synchronously from cache.
          final memosAsync = ref.read(memosProvider);
          final memo = memosAsync.valueOrNull?.firstWhere(
            (m) => m.id == id,
            orElse: () => throw StateError('Memo $id not found'),
          );
          return MemoEditorPage(memo: memo);
        },
      ),
    ],
  );
}
