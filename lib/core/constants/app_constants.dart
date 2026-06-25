/// App-wide shared constants.
///
/// Values here are load-bearing: changing them corrupts existing user data.
class AppConstants {
  AppConstants._();

  // @MX:ANCHOR: 'memos' box name is referenced by LocalDataSource and main.dart.
  // @MX:REASON: Renaming without a migration step deletes all user data.
  static const String memosBoxName = 'memos';

  // @MX:ANCHOR: typeId=0 MUST remain 0 — used by MemoModelAdapter.
  // @MX:REASON: Changing typeId corrupts existing Hive boxes.
  static const int memoModelTypeId = 0;

  // @MX:ANCHOR: [AUTO] 'pending_ops' box name — used by HivePendingOpStore and main.dart.
  // @MX:REASON: Renaming without a migration step deletes all queued offline ops
  //             (silent data loss for users with pending unsynced changes).
  static const String pendingOpsBoxName = 'pending_ops';
}
