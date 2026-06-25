import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_service.dart';

/// [NetworkChecker] implementation backed by [connectivity_plus].
///
/// Returns true when any non-none connectivity type is active.
class ConnectivityNetworkChecker implements NetworkChecker {
  ConnectivityNetworkChecker({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }
}
