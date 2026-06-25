// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memo_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$memoLocalDataSourceHash() =>
    r'memo_local_data_source_hash_placeholder';

/// See also [memoLocalDataSource].
@ProviderFor(memoLocalDataSource)
final memoLocalDataSourceProvider =
    AutoDisposeProvider<MemoLocalDataSource>.internal(
  memoLocalDataSource,
  name: r'memoLocalDataSourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$memoLocalDataSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MemoLocalDataSourceRef
    = AutoDisposeProviderRef<MemoLocalDataSource>;

String _$memoRepositoryHash() => r'memo_repository_hash_placeholder';

/// See also [memoRepository].
@ProviderFor(memoRepository)
final memoRepositoryProvider =
    AutoDisposeProvider<MemoRepository>.internal(
  memoRepository,
  name: r'memoRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$memoRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MemoRepositoryRef = AutoDisposeProviderRef<MemoRepository>;

String _$memosHash() => r'memos_hash_placeholder';

/// See also [Memos].
@ProviderFor(Memos)
final memosProvider =
    AutoDisposeAsyncNotifierProvider<Memos, List<Memo>>.internal(
  Memos.new,
  name: r'memosProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$memosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Memos = AutoDisposeAsyncNotifier<List<Memo>>;

String _$memoNotifierHash() => r'memo_notifier_hash_placeholder';

/// See also [MemoNotifier].
@ProviderFor(MemoNotifier)
final memoNotifierProvider =
    AutoDisposeNotifierProvider<MemoNotifier, void>.internal(
  MemoNotifier.new,
  name: r'memoNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$memoNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MemoNotifier = AutoDisposeNotifier<void>;
