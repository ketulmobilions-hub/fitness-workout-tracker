import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

/// Single [Connectivity] instance shared for the app's lifetime.
///
/// Isolated as a provider so that the platform channel is only opened once
/// and tests can cleanly override the stream source.
@Riverpod(keepAlive: true)
Connectivity connectivityInstance(Ref ref) => Connectivity();

/// Emits the latest list of [ConnectivityResult] whenever network status changes.
@Riverpod(keepAlive: true)
Stream<List<ConnectivityResult>> connectivity(Ref ref) {
  return ref.watch(connectivityInstanceProvider).onConnectivityChanged;
}

/// Convenience provider: `true` if at least one active connection exists.
///
/// - **Loading**: returns `true` (optimistic — device is likely online at startup)
/// - **Error**: returns `false` (fail-closed — don't assume connectivity on plugin failure)
/// - **Data**: `true` if any result is not [ConnectivityResult.none]
@Riverpod(keepAlive: true)
bool isConnected(Ref ref) {
  return ref.watch(connectivityProvider).when(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    error: (error, stackTrace) => false,
    loading: () => true,
  );
}
