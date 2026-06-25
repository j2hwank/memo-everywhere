// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memo_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$memoLocalDataSourceHash() =>
    r'20a3cce2b760c844014e88ff522840581901f126';

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

typedef MemoLocalDataSourceRef = AutoDisposeProviderRef<MemoLocalDataSource>;
String _$memoRepositoryHash() => r'8976e873fed767122f84b51b8b1f061c8ff9f314';

/// See also [memoRepository].
@ProviderFor(memoRepository)
final memoRepositoryProvider = AutoDisposeProvider<MemoRepository>.internal(
  memoRepository,
  name: r'memoRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$memoRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MemoRepositoryRef = AutoDisposeProviderRef<MemoRepository>;
String _$filteredMemosHash() => r'c8d5ec9fc0951abfd7b830e1ce2ce67c3f442d2a';

/// Combines [memosProvider] with [searchQueryProvider] to produce a filtered list.
/// Passes loading/error states through unchanged.
///
/// Copied from [filteredMemos].
@ProviderFor(filteredMemos)
final filteredMemosProvider =
    AutoDisposeProvider<AsyncValue<List<Memo>>>.internal(
  filteredMemos,
  name: r'filteredMemosProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$filteredMemosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FilteredMemosRef = AutoDisposeProviderRef<AsyncValue<List<Memo>>>;
String _$memosHash() => r'70de1357f43cbe524685bf63660d05424649426b';

/// Async notifier that loads and holds the memos list (updatedAt DESC).
///
/// Copied from [Memos].
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
String _$memoNotifierHash() => r'fbdfbb5e5346b65b40e85be815f3d692f2f73df3';

/// Notifier that exposes CRUD actions; each action invalidates [memosProvider]
/// so the list rebuilds automatically.
///
/// Copied from [MemoNotifier].
@ProviderFor(MemoNotifier)
final memoNotifierProvider =
    AutoDisposeNotifierProvider<MemoNotifier, void>.internal(
  MemoNotifier.new,
  name: r'memoNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$memoNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MemoNotifier = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
