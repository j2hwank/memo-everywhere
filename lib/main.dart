import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'data/models/memo_model.dart';

// @MX:ANCHOR bootstrap invariant — Hive must initialize before runApp.
// @MX:REASON: HiveFlutter stores data to the app documents directory which is
//             only available after WidgetsFlutterBinding.ensureInitialized().
//             Calling Hive.openBox before init or registering the adapter after
//             openBox both raise runtime errors.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MemoModelAdapter());
  await Hive.openBox<MemoModel>(AppConstants.memosBoxName);

  runApp(const ProviderScope(child: MemoApp()));
}

class MemoApp extends ConsumerWidget {
  const MemoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Memo Everywhere',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
