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
}
